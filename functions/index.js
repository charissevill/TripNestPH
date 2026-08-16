const crypto = require('node:crypto');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// Both read via Secret Manager (`firebase functions:secrets:set NAME`), never
// from a client-readable source — see `aiComplete`/`placesSearch*` below.
const groqApiKey = defineSecret('GROQ_API_KEY');
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

/**
 * Per-uid, per-function rolling-window request cap, backed by one small
 * Firestore doc per (uid, key) pair — so a scripted or compromised client
 * can't run up billing on Groq/Places/Routes under a single signed-in
 * account. A rolling window (recent timestamps, not a fixed bucket) so a
 * burst right at a bucket boundary can't double the effective limit; a
 * transaction makes the read-check-write atomic against concurrent calls
 * from the same user. Throws `resource-exhausted`, which every caller here
 * already has to handle (it's the same code Groq's own 429 maps to above).
 */
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

async function enforceRateLimit(uid, key, limit) {
  const ref = db.collection('rate_limits').doc(`${uid}_${key}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = Array.isArray(snap.data()?.timestamps) ? snap.data().timestamps : [];
    const recent = existing.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
    if (recent.length >= limit) {
      throw new HttpsError('resource-exhausted', "You're doing that too often — please wait a bit and try again.");
    }
    recent.push(now);
    tx.set(ref, { timestamps: recent, updatedAt: now });
  });
}

/**
 * Signs a real Google Places photo resource name (`places/{id}/photos/{id2}`)
 * into an opaque token the client can round-trip unchanged through
 * `PlacesService.photoUrl()` with zero Dart-side changes — see `placesPhoto`
 * below for why this exists and why it never expires.
 */
function signPlacesPhotoName(photoName, apiKey) {
  const encodedName = Buffer.from(photoName, 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', apiKey).update(photoName).digest('hex');
  return `${encodedName}.${sig}`;
}

function attachPhotoSignatures(places, apiKey) {
  for (const place of places ?? []) {
    if (!Array.isArray(place.photos)) continue;
    for (const photo of place.photos) {
      if (typeof photo?.name === 'string') {
        photo.name = signPlacesPhotoName(photo.name, apiKey);
      }
    }
  }
  return places;
}

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
 * Proxies Groq's OpenAI-compatible chat-completions endpoint so the raw API
 * key never has to ship inside the mobile/web client bundle. `flutter_dotenv`
 * loads `.env` as a plain app asset — anyone who unzips the APK/web build can
 * read it verbatim, which is a real exposure for a billed-per-token key.
 * Requires sign-in (same as every screen that can reach this — the app's
 * router redirects unauthenticated users to Login before they can open the
 * AI Planner or Trip Assistant at all, so this adds no new restriction).
 *
 * Swapped from OpenAI to Groq (temporary — see `groqApiKey` above); the
 * request/response shape is identical (`choices[0].message.content`,
 * `response_format: { type: 'json_object' }`), so nothing on the client
 * (`OpenAiService`) needed to change to point at a different provider.
 */
// The itinerary planner's own request (the biggest legitimate caller, see
// ItineraryPrompts) tops out well under these — generous enough for real
// usage, but enough of a ceiling that a scripted client can't run up
// billing by requesting huge completions or huge input payloads.
const AI_MAX_TOKENS_CEILING = 3000;
const AI_MAX_MESSAGES = 40;
// The Trip Assistant's system prompt alone runs ~3000 chars, plus a
// real-data grounding context (featured destinations/restaurants/province
// guides with links, hotlines, tips, budgets) that can legitimately push
// well past a smaller ceiling — this is trusted, app-authored content, not
// attacker-controlled input, so the cap here just needs to stop a truly
// runaway payload, not squeeze normal usage.
const AI_MAX_MESSAGE_CHARS = 16000;
const GROQ_MODEL = 'llama-3.3-70b-versatile';

exports.aiComplete = onCall({ region: 'asia-southeast1', secrets: [groqApiKey], timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'aiComplete', 30);

  const apiKey = groqApiKey.value();
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
    model: GROQ_MODEL,
    messages,
    temperature: typeof temperature === 'number' ? temperature : 0.7,
    max_tokens: boundedMaxTokens,
  };
  if (jsonMode) body.response_format = { type: 'json_object' };

  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
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
  if (response.status === 401) throw new HttpsError('failed-precondition', apiMessage || 'The Groq API key is invalid.');
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
  await enforceRateLimit(request.auth.uid, 'placesSearchNearby', 120);
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
    if (response.status !== 200) {
      console.error('placesSearchNearby: Places API returned', response.status, await response.text().catch(() => ''));
      return { places: [] };
    }
    const json = await response.json().catch(() => null);
    return { places: attachPhotoSignatures(json?.places ?? [], apiKey) };
  } catch (e) {
    console.error('placesSearchNearby: request failed', e);
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
  await enforceRateLimit(request.auth.uid, 'placesSearchText', 120);
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
    if (response.status !== 200) {
      console.error('placesSearchText: Places API returned', response.status, await response.text().catch(() => ''));
      return { places: [] };
    }
    const json = await response.json().catch(() => null);
    return { places: attachPhotoSignatures(json?.places ?? [], apiKey) };
  } catch (e) {
    console.error('placesSearchText: request failed', e);
    return { places: [] };
  }
});

/**
 * Proxies Routes API `computeRoutes` so the Trip Route map can draw a real,
 * road-following path (plus per-leg travel time) instead of a straight line
 * between stops. Same key-exposure reasoning as the Places functions above
 * — bills under the same Maps Platform project/key, but needs "Routes API"
 * separately enabled there. Best-effort: any upstream failure returns a
 * "no route" result rather than throwing, since the client always has a
 * straight-line fallback and this is a pure enhancement, never worth
 * failing the itinerary screen over.
 */
exports.computeTripRoute = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'computeTripRoute', 60);
  const apiKey = googlePlacesApiKey.value();
  if (!apiKey) return { encodedPolyline: null, legs: [] };

  const { waypoints } = request.data ?? {};
  if (!Array.isArray(waypoints) || waypoints.length < 2) {
    throw new HttpsError('invalid-argument', 'At least 2 waypoints are required.');
  }
  if (waypoints.length > 25) {
    throw new HttpsError('invalid-argument', 'Too many waypoints for a single route.');
  }
  for (const w of waypoints) {
    if (typeof w?.latitude !== 'number' || typeof w?.longitude !== 'number') {
      throw new HttpsError('invalid-argument', 'Each waypoint needs latitude and longitude.');
    }
  }

  const toWaypoint = (w) => ({ location: { latLng: { latitude: w.latitude, longitude: w.longitude } } });

  try {
    const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters',
      },
      body: JSON.stringify({
        origin: toWaypoint(waypoints[0]),
        destination: toWaypoint(waypoints[waypoints.length - 1]),
        intermediates: waypoints.slice(1, -1).map(toWaypoint),
        travelMode: 'DRIVE',
        polylineQuality: 'OVERVIEW',
      }),
    });
    if (response.status !== 200) {
      const errorBody = await response.text().catch(() => '');
      console.error('computeTripRoute: Routes API returned', response.status, errorBody);
      return { encodedPolyline: null, legs: [] };
    }
    const json = await response.json().catch(() => null);
    const route = json?.routes?.[0];
    if (!route) {
      console.error('computeTripRoute: no route in Routes API response', JSON.stringify(json));
      return { encodedPolyline: null, legs: [] };
    }

    const legs = (route.legs ?? []).map((leg) => ({
      // Duration comes back as a string like "1234s".
      durationSeconds: parseInt(leg.duration ?? '0', 10) || 0,
      distanceMeters: leg.distanceMeters ?? 0,
    }));
    return { encodedPolyline: route.polyline?.encodedPolyline ?? null, legs };
  } catch (e) {
    console.error('computeTripRoute: request failed', e);
    return { encodedPolyline: null, legs: [] };
  }
});

/**
 * Proxies a single Places photo's bytes so `photoUrl()` never has to embed
 * the raw API key in a URL handed to `CachedNetworkImage` (which can't
 * attach a Firebase Auth header the way the callable functions above use).
 * Deliberately public/unauthenticated (no Firebase Auth check) — but NOT a
 * free-for-all forwarder: `photoName` must be one of the signed tokens
 * `attachPhotoSignatures` mints inside the authenticated
 * `placesSearchNearby`/`placesSearchText` calls above, so a request for an
 * arbitrary Google Places photo this app never actually surfaced is
 * rejected before it ever reaches (and bills) the upstream API. The
 * signature never expires — this is a request-provenance check ("did our
 * own search functions vouch for this exact name"), not a short-lived
 * capability token — so a photoUrl already baked into a saved itinerary
 * months ago keeps working.
 */
// Google's own Places API (New) photo resource name shape:
// places/{placeId}/photos/{photoId}.
const PLACES_PHOTO_NAME_PATTERN = /^places\/[^/]+\/photos\/[^/]+$/;

function verifySignedPlacesPhotoToken(token, apiKey) {
  const lastDot = token.lastIndexOf('.');
  if (lastDot === -1) return null;
  const encodedName = token.slice(0, lastDot);
  const sig = token.slice(lastDot + 1);

  let photoName;
  try {
    photoName = Buffer.from(encodedName, 'base64url').toString('utf8');
  } catch {
    return null;
  }
  if (!PLACES_PHOTO_NAME_PATTERN.test(photoName)) return null;

  const expected = crypto.createHmac('sha256', apiKey).update(photoName).digest();
  let provided;
  try {
    provided = Buffer.from(sig, 'hex');
  } catch {
    return null;
  }
  if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) return null;
  return photoName;
}

exports.placesPhoto = onRequest({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (req, res) => {
  const apiKey = googlePlacesApiKey.value();
  const token = req.query.photoName;
  const photoName = apiKey && typeof token === 'string' ? verifySignedPlacesPhotoToken(token, apiKey) : null;
  if (!photoName) {
    res.status(403).send('Forbidden');
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

/**
 * A "Travelers say..." summary generated from a listing's own review text —
 * refreshed on a schedule (never on-demand from the app), so opening a
 * details page is never what triggers a billed Groq call. Restaurants only
 * for now: they're the one review target type with enough real review
 * volume in this app to make a summary worth the API cost.
 */
const REVIEW_DIGEST_MIN_REVIEWS = 3;
// A digest is only worth regenerating once enough new reviews have come in
// since the last one — otherwise every run would spend a Groq call on every
// popular listing for a summary that would barely have changed.
const REVIEW_DIGEST_MIN_NEW_REVIEWS = 3;

/**
 * Same Groq chat-completions endpoint `aiComplete` proxies, called directly
 * here instead of through it — `aiComplete` is a client-facing callable with
 * its own auth/rate-limit/argument-validation wrapper that makes no sense
 * for a server-triggered scheduled job, so this is a separate, minimal path
 * to the same upstream API rather than a refactor of that tested function.
 */
async function summarizeReviews(apiKey, placeName, comments) {
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      temperature: 0.4,
      max_tokens: 220,
      messages: [
        {
          role: 'system',
          content:
            'You summarize real traveler reviews into one short, honest "Travelers say" paragraph (2-3 sentences, under 400 characters) for a Philippine tourism app. Base it ONLY on the review text given — never invent a detail, name, or complaint not actually present in it. Reflect a genuine mix of praise and any real recurring criticism, if there is one. Neutral third-person summary voice, no bullet points, no markdown, no preamble like "Travelers say" (the UI already labels it that way).',
        },
        {
          role: 'user',
          content: `Reviews for "${placeName}":\n${comments.map((c, i) => `${i + 1}. ${c}`).join('\n')}\n\nWrite the summary now.`,
        },
      ],
    }),
  });
  if (response.status !== 200) {
    const json = await response.json().catch(() => null);
    throw new Error(`Groq request failed (${response.status}): ${json?.error?.message ?? 'unknown error'}`);
  }
  const json = await response.json();
  const content = json?.choices?.[0]?.message?.content;
  if (!content || !content.trim()) throw new Error('Groq returned an empty response.');
  return content.trim();
}

/**
 * Writes one `analytics_snapshots/{YYYY-MM-DD}` doc per day with the same
 * platform-wide counts `AdminAnalyticsScreen` already computes live on
 * demand — this doesn't replace that live query, it just gives the
 * dashboard a history to chart trend lines against, which a single current
 * snapshot can never show on its own. `count()` aggregation queries so this
 * scales with collection count, not document count, the same reasoning
 * `UserRepository.countAll()` etc. already use client-side.
 */
exports.snapshotDailyAnalytics = onSchedule(
  { region: 'asia-southeast1', schedule: 'every day 00:10' },
  async () => {
    const count = async (query) => (await query.count().get()).data().count;

    const [
      travelerCount,
      suspendedTravelerCount,
      publishedDestinationCount,
      publishedRestaurantCount,
      publishedFestivalCount,
      pendingBusinessCount,
      approvedBusinessCount,
      savedTripCount,
      pendingReportCount,
    ] = await Promise.all([
      count(db.collection('users')),
      count(db.collection('users').where('status', '==', 'suspended')),
      count(db.collection('tourist_spots').where('status', '==', 'published')),
      count(db.collection('restaurants').where('status', '==', 'published')),
      count(db.collection('festivals').where('status', '==', 'published')),
      count(db.collection('businesses').where('status', '==', 'pending')),
      count(db.collection('businesses').where('status', '==', 'approved')),
      count(db.collection('saved_itineraries')),
      // Handled reports are deleted (see AdminReportedReviewsScreen), never
      // left in a "resolved" state — so every doc still in this collection
      // is, by definition, still pending.
      count(db.collection('review_reports')),
    ]);

    // UTC date key — a day boundary a few hours off from the traveler base's
    // actual local time doesn't matter for a long-run trend line, and this
    // keeps the key trivially derivable/sortable without a timezone lookup.
    const dateKey = new Date().toISOString().slice(0, 10);
    await db
      .collection('analytics_snapshots')
      .doc(dateKey)
      .set({
        date: dateKey,
        travelerCount,
        suspendedTravelerCount,
        publishedDestinationCount,
        publishedRestaurantCount,
        publishedFestivalCount,
        pendingBusinessCount,
        approvedBusinessCount,
        savedTripCount,
        pendingReportCount,
        createdAt: FieldValue.serverTimestamp(),
      });
  },
);

exports.generateReviewDigests = onSchedule(
  { region: 'asia-southeast1', schedule: 'every 24 hours', secrets: [groqApiKey], timeoutSeconds: 540 },
  async () => {
    const apiKey = groqApiKey.value();
    if (!apiKey) return;

    const listingsSnap = await db.collection('restaurants').where('status', '==', 'published').get();

    for (const doc of listingsSnap.docs) {
      const data = doc.data();
      const reviewCount = data.reviewCount ?? 0;
      if (reviewCount < REVIEW_DIGEST_MIN_REVIEWS) continue;

      const existingDigest = data.reviewDigest;
      const alreadyCovered = existingDigest?.reviewCountAtGeneration ?? 0;
      if (existingDigest && reviewCount - alreadyCovered < REVIEW_DIGEST_MIN_NEW_REVIEWS) continue;

      try {
        const reviewsSnap = await db
          .collection('reviews')
          .where('targetId', '==', doc.id)
          .where('targetType', '==', 'restaurant')
          .where('isHidden', '==', false)
          .limit(50)
          .get();
        const comments = reviewsSnap.docs
          .map((d) => d.data().comment)
          .filter((c) => typeof c === 'string' && c.trim().length > 0);
        if (comments.length < REVIEW_DIGEST_MIN_REVIEWS) continue;

        const summary = await summarizeReviews(apiKey, data.name ?? 'this place', comments);
        await doc.ref.update({
          reviewDigest: {
            summary,
            reviewCountAtGeneration: comments.length,
            generatedAt: FieldValue.serverTimestamp(),
          },
        });
      } catch (e) {
        // Best-effort — one bad listing (a transient Groq error, say)
        // shouldn't stop the rest of this run from generating theirs.
        console.error(`generateReviewDigests: failed for restaurants/${doc.id}`, e);
      }
    }
  },
);
