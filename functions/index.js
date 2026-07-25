const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// Both read via Secret Manager (`firebase functions:secrets:set NAME`), never
// from a client-readable source — see `aiComplete`/`placesSearch*` below.
const openaiApiKey = defineSecret('OPENAI_API_KEY');
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

/**
 * Mirrors the CALLER's OWN `admin_users/{uid}` doc into their Auth custom
 * claims (`adminRole`/`adminStatus`) and returns the values it set.
 *
 * This exists because `storage.rules` needs to know a user's Admin Portal
 * role, but Storage security rules can only reach Firestore through the
 * `firestore.get()`/`firestore.exists()` cross-service bridge — which is
 * unreliable in practice on this project (confirmed by direct testing: an
 * owner-only Storage write with no Firestore lookup succeeds, but the
 * moment a rule needs `firestore.get(admin_users/{uid})` it fails with a
 * bare "Permission denied", even though the document is correct). Custom
 * claims sidestep that bridge entirely: they're baked into the ID token,
 * so storage.rules reads `request.auth.token.adminRole` directly with zero
 * cross-service calls — the standard Firebase-recommended pattern for
 * exactly this "role gates Storage access" scenario.
 *
 * Deliberately a *callable* function, not a Firestore `onDocumentWritten`
 * trigger: this project's Firestore→Eventarc event delivery proved
 * unreliable too (verified directly against Cloud Run request logs — zero
 * invocations ever arrived for a documented test write), so a trigger-based
 * sync could silently never run. A direct client call has no such
 * dependency and gives the caller a definite success/failure instead of a
 * black box.
 *
 * Safe to expose to any signed-in user: it only ever mirrors the caller's
 * OWN admin_users doc (never another uid), and that doc's content is
 * itself already protected by firestore.rules — this function can't grant
 * anyone a role Firestore doesn't already say they have.
 *
 * The caller must still force-refresh their ID token after this resolves
 * (`getIdTokenResult(forceRefresh: true)`) for the new claims to actually
 * take effect — setting a custom claim doesn't retroactively change a
 * token already in the client's hands.
 */
exports.syncMyAdminClaims = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const doc = await db.collection('admin_users').doc(uid).get();
  const claims = doc.exists ? { adminRole: doc.data().role ?? null, adminStatus: doc.data().status ?? null } : { adminRole: null, adminStatus: null };
  await auth.setCustomUserClaims(uid, claims);
  return claims;
});

/**
 * Proxies OpenAI's chat-completions endpoint so the raw API key never has
 * to ship inside the mobile/web client bundle. `flutter_dotenv` loads
 * `.env` as a plain app asset — anyone who unzips the APK/web build can
 * read it verbatim, which is a real exposure for a billed-per-token key.
 * Requires sign-in (same as every screen that can reach this — the app's
 * router redirects unauthenticated users to Login before they can open the
 * AI Planner or Trip Assistant at all, so this adds no new restriction).
 */
// The itinerary planner's own request (the biggest legitimate caller, see
// ItineraryPrompts) tops out well under these — generous enough for real
// usage, but enough of a ceiling that a scripted client can't run up
// OpenAI billing by requesting huge completions or huge input payloads.
const AI_MAX_TOKENS_CEILING = 3000;
const AI_MAX_MESSAGES = 40;
const AI_MAX_MESSAGE_CHARS = 6000;

exports.aiComplete = onCall({ region: 'asia-southeast1', secrets: [openaiApiKey], timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');

  const apiKey = openaiApiKey.value();
  if (!apiKey) throw new HttpsError('failed-precondition', 'AI features aren\'t set up yet.');

  const { messages, temperature, maxTokens, jsonMode } = request.data ?? {};
  if (!Array.isArray(messages) || messages.length === 0) {
    throw new HttpsError('invalid-argument', 'messages is required.');
  }
  if (messages.length > AI_MAX_MESSAGES) {
    throw new HttpsError('invalid-argument', 'Too many messages in this request.');
  }
  for (const m of messages) {
    if (typeof m?.content !== 'string' || m.content.length > AI_MAX_MESSAGE_CHARS) {
      throw new HttpsError('invalid-argument', 'One of the messages is invalid or too long.');
    }
  }

  const boundedMaxTokens = typeof maxTokens === 'number' ? Math.min(Math.max(Math.trunc(maxTokens), 1), AI_MAX_TOKENS_CEILING) : 1200;
  const body = {
    model: 'gpt-4o',
    messages,
    temperature: typeof temperature === 'number' ? temperature : 0.7,
    max_tokens: boundedMaxTokens,
  };
  if (jsonMode) body.response_format = { type: 'json_object' };

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify(body),
  });
  const json = await response.json().catch(() => null);

  if (response.status === 200) {
    const content = json?.choices?.[0]?.message?.content;
    if (!content || !content.trim()) throw new HttpsError('internal', 'The AI returned an empty response. Please try again.');
    return { content };
  }
  const apiMessage = json?.error?.message;
  if (response.status === 401) throw new HttpsError('failed-precondition', apiMessage || 'The OpenAI API key is invalid.');
  if (response.status === 429) throw new HttpsError('resource-exhausted', 'Too many requests right now. Please wait a moment and try again.');
  if (response.status === 400) throw new HttpsError('invalid-argument', apiMessage || 'The AI could not process that request.');
  if (response.status >= 500) throw new HttpsError('unavailable', 'The AI service is temporarily unavailable. Please try again shortly.');
  throw new HttpsError('unknown', apiMessage || 'The AI service returned an unexpected error.');
});

// Deliberately narrow — Places API (New) bills by which field tier a
// request touches, not just call count — matches exactly what
// PlaceCard/PlaceDetailsSheet render, plus googleMapsUri/weekdayDescriptions/
// editorialSummary for AI grounding (real Maps links + hours + a short
// description the AI can cite instead of inventing one).
const PLACES_FIELD_MASK = 'places.id,places.displayName,places.types,places.photos,'
  + 'places.rating,places.userRatingCount,places.formattedAddress,places.location,'
  + 'places.priceLevel,places.currentOpeningHours.openNow,places.nationalPhoneNumber,'
  + 'places.websiteUri,places.googleMapsUri,places.regularOpeningHours.weekdayDescriptions,'
  + 'places.editorialSummary';

/**
 * Proxies Places API (New) `searchNearby` — same key-exposure reasoning as
 * `aiComplete`. Best-effort: any upstream failure returns an empty list
 * rather than throwing, matching `PlacesService`'s existing "a places
 * lookup is always supplementary, never worth failing a page over" design.
 */
exports.placesSearchNearby = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const apiKey = googlePlacesApiKey.value();
  if (!apiKey) return { places: [] };

  const { latitude, longitude, includedTypes, radiusMeters, maxResultCount } = request.data ?? {};
  if (typeof latitude !== 'number' || typeof longitude !== 'number' || !Array.isArray(includedTypes)) {
    throw new HttpsError('invalid-argument', 'latitude, longitude and includedTypes are required.');
  }

  try {
    const response = await fetch('https://places.googleapis.com/v1/places:searchNearby', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': PLACES_FIELD_MASK },
      body: JSON.stringify({
        includedTypes,
        maxResultCount: maxResultCount ?? 20,
        rankPreference: 'POPULARITY',
        locationRestriction: { circle: { center: { latitude, longitude }, radius: radiusMeters ?? 5000 } },
      }),
    });
    if (response.status !== 200) return { places: [] };
    const json = await response.json().catch(() => null);
    return { places: json?.places ?? [] };
  } catch (e) {
    return { places: [] };
  }
});

/**
 * Proxies Places API (New) `searchText` — used for province-level browsing
 * (provinces have no single coordinate) and any category with no dedicated
 * `includedTypes` entry (e.g. beaches). Same best-effort/key-exposure
 * reasoning as `placesSearchNearby`.
 */
exports.placesSearchText = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const apiKey = googlePlacesApiKey.value();
  if (!apiKey) return { places: [] };

  const { textQuery, maxResultCount, biasLatitude, biasLongitude, biasRadiusMeters } = request.data ?? {};
  if (typeof textQuery !== 'string' || !textQuery.trim()) {
    throw new HttpsError('invalid-argument', 'textQuery is required.');
  }

  const body = { textQuery, maxResultCount: maxResultCount ?? 20 };
  if (typeof biasLatitude === 'number' && typeof biasLongitude === 'number') {
    body.locationBias = { circle: { center: { latitude: biasLatitude, longitude: biasLongitude }, radius: biasRadiusMeters ?? 15000 } };
  }

  try {
    const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': PLACES_FIELD_MASK },
      body: JSON.stringify(body),
    });
    if (response.status !== 200) return { places: [] };
    const json = await response.json().catch(() => null);
    return { places: json?.places ?? [] };
  } catch (e) {
    return { places: [] };
  }
});

/**
 * Proxies a single Places photo's bytes so `photoUrl()` never has to embed
 * the raw API key in a URL handed to `CachedNetworkImage` (which can't
 * attach a Firebase Auth header the way the callable functions above use).
 * Deliberately public/unauthenticated — the cost surface of a photo fetch
 * is small and bounded, unlike `aiComplete`/`placesSearch*`, and this way
 * the underlying key is still never extractable from the client either way.
 */
// Google's own Places API (New) photo resource name shape:
// places/{placeId}/photos/{photoId}. Rejecting anything else stops this
// public, unauthenticated proxy from being used as a free-form forwarder
// to arbitrary paths under places.googleapis.com with our billed API key.
const PLACES_PHOTO_NAME_PATTERN = /^places\/[^/]+\/photos\/[^/]+$/;

exports.placesPhoto = onRequest({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (req, res) => {
  const apiKey = googlePlacesApiKey.value();
  const photoName = req.query.photoName;
  if (!apiKey || typeof photoName !== 'string' || !PLACES_PHOTO_NAME_PATTERN.test(photoName)) {
    res.status(400).send('Bad request');
    return;
  }
  // Clamped rather than passed through raw, so this can't be abused to
  // request absurdly large (expensive) images either.
  const requestedWidth = Number(req.query.maxWidthPx);
  const maxWidthPx = Number.isFinite(requestedWidth) ? Math.min(Math.max(Math.trunc(requestedWidth), 1), 1600) : 800;
  try {
    const upstream = await fetch(
      `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=${maxWidthPx}&key=${apiKey}`,
    );
    if (!upstream.ok) {
      res.status(upstream.status).send('Upstream error');
      return;
    }
    res.set('Content-Type', upstream.headers.get('content-type') || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=86400');
    res.status(200).send(Buffer.from(await upstream.arrayBuffer()));
  } catch (e) {
    res.status(502).send('Proxy error');
  }
});

// FCM's multicast send caps out at 500 tokens per call.
const FCM_BATCH_SIZE = 500;

function chunk(array, size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

/**
 * Every `notifications` doc NotificationRepository writes (a traveler
 * review reply is the only other writer, but that path doesn't exist yet)
 * — personal (`userId` set) or broadcast (`userId` == '', see
 * `NotificationRepository.createBroadcast`) — triggers this and gets
 * delivered as a real OS-level push via FCM, on top of the in-app
 * notification bell the mobile app already reads directly from Firestore.
 */
exports.sendPushOnNotificationCreated = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const notification = event.data?.data();
  if (!notification) return;

  const { userId, title, body, category, relatedId } = notification;
  if (!title || !body) return;

  const tokens = userId ? await tokensForUser(userId) : await tokensForAllUsers();
  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: {
      category: category ?? 'general',
      relatedId: relatedId ?? '',
      notificationId: event.params.notificationId,
    },
    android: { notification: { channelId: 'tripnest_default' } },
  };

  for (const batch of chunk(tokens, FCM_BATCH_SIZE)) {
    const response = await messaging.sendEachForMulticast({ ...message, tokens: batch });
    await pruneInvalidTokens(batch, response);
  }
});

async function tokensForUser(userId) {
  const doc = await db.collection('users').doc(userId).get();
  const data = doc.data();
  return Array.isArray(data?.fcmTokens) ? data.fcmTokens : [];
}

async function tokensForAllUsers() {
  const snapshot = await db.collection('users').select('fcmTokens').get();
  const tokens = [];
  for (const doc of snapshot.docs) {
    const docTokens = doc.data().fcmTokens;
    if (Array.isArray(docTokens)) tokens.push(...docTokens);
  }
  return tokens;
}

/**
 * A device that uninstalled the app or cleared its FCM registration leaves
 * a stale token in `users/{uid}.fcmTokens` forever unless something removes
 * it — best-effort cleanup so that array doesn't grow unbounded and every
 * broadcast doesn't keep re-attempting known-dead tokens.
 */
async function pruneInvalidTokens(tokens, response) {
  const { FieldValue } = require('firebase-admin/firestore');
  const invalid = [];
  response.responses.forEach((result, i) => {
    const code = result.error?.code;
    if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
      invalid.push(tokens[i]);
    }
  });
  if (invalid.length === 0) return;

  const snapshot = await db.collection('users').where('fcmTokens', 'array-contains-any', invalid.slice(0, 30)).get();
  await Promise.all(snapshot.docs.map((doc) => doc.ref.update({ fcmTokens: FieldValue.arrayRemove(...invalid) })));
}
