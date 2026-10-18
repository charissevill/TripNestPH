const crypto = require('node:crypto');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');
const { parsePermitFields, linesFromVision } = require('./permit_parser');
const { parseIdName } = require('./id_parser');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// Both read via Secret Manager (`firebase functions:secrets:set NAME`), never
// from a client-readable source — see `aiComplete`/`placesSearch*` below.
const openAiApiKey = defineSecret('OPENAI_API_KEY');
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

/**
 * Per-uid, per-function rolling-window request cap, backed by one small
 * Firestore doc per (uid, key) pair — so a scripted or compromised client
 * can't run up billing on OpenAI/Places/Routes under a single signed-in
 * account. A rolling window (recent timestamps, not a fixed bucket) so a
 * burst right at a bucket boundary can't double the effective limit; a
 * transaction makes the read-check-write atomic against concurrent calls
 * from the same user. Throws `resource-exhausted`, which every caller here
 * already has to handle (it's the same code OpenAI's own 429 maps to above).
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

// ---- Numeric-code password reset / email verification -------------------
// Replaces Firebase Auth's default link-based emails, which were landing in
// spam (generic `noreply@<project>.firebaseapp.com` sender, no branding)
// and whose one-time links kept coming back "expired or already used" —
// partly because each new request invalidates the previous link, partly
// because some inboxes' link-safety scanners pre-fetch (and so pre-consume)
// the link before a traveler manually clicks it. A 6-digit code typed by
// hand has neither failure mode, and sending our own HTML email means it
// can actually look like it's from TripNest PH.
//
// Delivery: writing to the `mail` collection here is picked up by the
// Firebase Extension `firebase/firestore-send-email` (Trigger Email),
// configured separately with the project owner's own Gmail SMTP app
// password — this function only ever writes the trigger doc, never talks
// to SMTP directly.
const OTP_TTL_MS = 10 * 60 * 1000;
// 6 digits is ~1M combinations — trivially brute-forceable with no attempt
// cap, so a wrong guess is capped well before that space could be searched.
const OTP_MAX_ATTEMPTS = 5;

function generateOtpCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

// Only the hash is ever stored — a stray Firestore read (a bug, a console
// click) can't hand out a directly-usable code, same "trust the shape,
// protect the data" posture as the rest of this file's secrets handling.
function hashOtp(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

// Deterministic per (purpose, email): a fresh request naturally overwrites
// whatever code was issued before, matching how Firebase's own link flow
// already invalidates a prior link once a new one is requested — a
// traveler never ends up with two simultaneously-valid codes.
function otpDocId(purpose, email) {
  return crypto.createHash('sha256').update(`${purpose}:${email.toLowerCase().trim()}`).digest('hex');
}

// Colors match AppLogo's own artwork (assets/images/logo.png — the pin
// mark's blue gradient is exactly AppColors.oceanGradient, its "TRIP"
// wordmark a dark navy, its tagline underline a warm gold) rather than the
// separate teal palette the in-app auth screens use, so this email reads as
// visibly the same brand as the logo a traveler already recognizes.
const LOGO_URL = 'https://tripnest-ph.web.app/assets/assets/images/logo.png';

// Individual bordered digit boxes (a `<table>`, not flex/grid — the one
// concession to old email clients like Outlook, which silently drop those)
// read as a more deliberately-designed code than one spaced-out string.
function codeDigitBoxes(code) {
  const digitCell = (digit) =>
    `<td style="width:44px;height:54px;text-align:center;vertical-align:middle;background:#E8F4FC;border:1.5px solid #BFE0F5;border-radius:10px;font-family:'Courier New',monospace;font-size:26px;font-weight:700;color:#0F6FA6;">${digit}</td>`;
  const gapCell = '<td style="width:6px;"></td>';
  return code.split('').map(digitCell).join(gapCell);
}

function otpEmailHtml({ heading, intro, code }) {
  return `<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#F1F6FA;padding:40px 16px;">
  <div style="max-width:480px;margin:0 auto;background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 8px 28px rgba(15,111,166,0.14);">
    <div style="background:linear-gradient(135deg,#2D9CDB,#0F6FA6);padding:36px 32px 30px;text-align:center;">
      <img src="${LOGO_URL}" alt="TripNest PH" width="100" height="100" style="display:block;margin:0 auto 14px;background:transparent;">
      <div style="color:#FFFFFF;font-size:12.5px;font-weight:700;letter-spacing:0.2em;text-transform:uppercase;">TripNest PH</div>
    </div>
    <div style="padding:36px 32px 32px;">
      <h1 style="margin:0 0 10px;font-size:23px;font-weight:700;color:#173A5E;letter-spacing:-0.01em;">${heading}</h1>
      <p style="margin:0 0 28px;font-size:15px;color:#5B7085;line-height:1.6;">${intro}</p>
      <table role="presentation" align="center" cellpadding="0" cellspacing="0" style="margin:0 auto;">
        <tr>${codeDigitBoxes(code)}</tr>
      </table>
      <p style="text-align:center;margin:16px 0 28px;font-size:13px;color:#8CA3B5;">Expires in 10 minutes</p>
      <div style="background:#F7FAFD;border:1px solid #E3EEF5;border-radius:12px;padding:16px 18px;">
        <p style="margin:0;font-size:13px;color:#5B7085;line-height:1.5;">Didn't request this? You can safely ignore this email — your account is still secure.</p>
      </div>
      <div style="height:3px;width:56px;background:#F2C94C;border-radius:2px;margin-top:28px;"></div>
    </div>
  </div>
  <p style="text-align:center;font-size:12px;color:#8CA3B5;margin-top:20px;letter-spacing:0.02em;">TripNest PH &middot; Discover the Philippines, one destination at a time.</p>
</div>`;
}

/**
 * Requests a password-reset code for [email]. Deliberately returns success
 * whether or not an account exists for that email — an `invalid-argument`/
 * `not-found` split here would let a caller enumerate registered emails one
 * attempt at a time, the same reasoning `AuthService.sendPasswordResetEmail`
 * already applies to Firebase's own link-based send.
 */
exports.requestPasswordResetCode = onCall({ region: 'asia-southeast1' }, async (request) => {
  const email = typeof request.data?.email === 'string' ? request.data.email.trim().toLowerCase() : '';
  if (!email) throw new HttpsError('invalid-argument', 'A valid email is required.');

  await enforceRateLimit(email, 'passwordResetRequest', 5);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch (e) {
    return { success: true };
  }

  const code = generateOtpCode();
  await db.collection('otp_codes').doc(otpDocId('password_reset', email)).set({
    email,
    purpose: 'password_reset',
    codeHash: hashOtp(code),
    attempts: 0,
    expiresAt: Date.now() + OTP_TTL_MS,
  });

  await db.collection('mail').add({
    to: email,
    message: {
      subject: 'Your TripNest PH password reset code',
      html: otpEmailHtml({
        heading: 'Reset your password',
        intro: `Hi ${userRecord.displayName || 'there'}, use the code below to reset your TripNest PH password.`,
        code,
      }),
    },
  });

  return { success: true };
});

/**
 * Verifies a password-reset code and, on success, sets the account's new
 * password directly via the Admin SDK — the one operation here that
 * genuinely requires it, since the client SDK can only ever change the
 * password of the session it's currently signed into, never an arbitrary
 * account by email.
 */
exports.verifyPasswordResetCode = onCall({ region: 'asia-southeast1' }, async (request) => {
  const email = typeof request.data?.email === 'string' ? request.data.email.trim().toLowerCase() : '';
  const code = typeof request.data?.code === 'string' ? request.data.code.trim() : '';
  const newPassword = typeof request.data?.newPassword === 'string' ? request.data.newPassword : '';
  if (!email || !code) throw new HttpsError('invalid-argument', 'Email and code are required.');
  // Mirrors Validators.password's own 8-character minimum client-side —
  // defense in depth, same as every other isValid*() check in this project.
  if (newPassword.length < 8) throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');

  const ref = db.collection('otp_codes').doc(otpDocId('password_reset', email));
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('invalid-argument', 'Invalid or expired code. Please request a new one.');
  const data = snap.data();

  if (Date.now() > data.expiresAt) {
    await ref.delete();
    throw new HttpsError('invalid-argument', 'This code has expired. Please request a new one.');
  }
  if ((data.attempts ?? 0) >= OTP_MAX_ATTEMPTS) {
    await ref.delete();
    throw new HttpsError('resource-exhausted', 'Too many incorrect attempts. Please request a new code.');
  }
  if (hashOtp(code) !== data.codeHash) {
    await ref.update({ attempts: FieldValue.increment(1) });
    throw new HttpsError('invalid-argument', 'Incorrect code. Please try again.');
  }

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch (e) {
    await ref.delete();
    throw new HttpsError('invalid-argument', 'Invalid or expired code. Please request a new one.');
  }

  await auth.updateUser(userRecord.uid, { password: newPassword });
  await ref.delete();
  return { success: true };
});

/**
 * Requests an email-verification code for the caller's own account —
 * authenticated (unlike the password-reset pair above) since a traveler
 * already has a session at this point in the sign-up flow.
 */
exports.requestEmailVerificationCode = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(uid, 'emailVerifyRequest', 5);

  const userRecord = await auth.getUser(uid);
  if (!userRecord.email) throw new HttpsError('failed-precondition', 'This account has no email on file.');
  if (userRecord.emailVerified) return { success: true, alreadyVerified: true };

  const code = generateOtpCode();
  await db.collection('otp_codes').doc(otpDocId('email_verify', userRecord.email)).set({
    email: userRecord.email,
    uid,
    purpose: 'email_verify',
    codeHash: hashOtp(code),
    attempts: 0,
    expiresAt: Date.now() + OTP_TTL_MS,
  });

  await db.collection('mail').add({
    to: userRecord.email,
    message: {
      subject: 'Verify your TripNest PH email',
      html: otpEmailHtml({
        heading: 'Verify your email',
        intro: `Hi ${userRecord.displayName || 'there'}, use the code below to verify your TripNest PH account.`,
        code,
      }),
    },
  });

  return { success: true };
});

/**
 * Verifies an email-verification code and flips `emailVerified` on the
 * caller's own Auth record via the Admin SDK (the client SDK has no way to
 * set that flag directly — it only ever becomes true by consuming
 * Firebase's own link, which this replaces).
 */
exports.verifyEmailVerificationCode = onCall({ region: 'asia-southeast1' }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  const code = typeof request.data?.code === 'string' ? request.data.code.trim() : '';
  if (!code) throw new HttpsError('invalid-argument', 'A code is required.');

  const userRecord = await auth.getUser(uid);
  if (!userRecord.email) throw new HttpsError('failed-precondition', 'This account has no email on file.');

  const ref = db.collection('otp_codes').doc(otpDocId('email_verify', userRecord.email));
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('invalid-argument', 'Invalid or expired code. Please request a new one.');
  const data = snap.data();

  if (data.uid !== uid) throw new HttpsError('permission-denied', 'This code doesn\'t belong to your account.');
  if (Date.now() > data.expiresAt) {
    await ref.delete();
    throw new HttpsError('invalid-argument', 'This code has expired. Please request a new one.');
  }
  if ((data.attempts ?? 0) >= OTP_MAX_ATTEMPTS) {
    await ref.delete();
    throw new HttpsError('resource-exhausted', 'Too many incorrect attempts. Please request a new code.');
  }
  if (hashOtp(code) !== data.codeHash) {
    await ref.update({ attempts: FieldValue.increment(1) });
    throw new HttpsError('invalid-argument', 'Incorrect code. Please try again.');
  }

  await auth.updateUser(uid, { emailVerified: true });
  await ref.delete();
  return { success: true };
});

/**
 * Proxies OpenAI's chat-completions endpoint so the raw API
 * key never has to ship inside the mobile/web client bundle. `flutter_dotenv`
 * loads `.env` as a plain app asset — anyone who unzips the APK/web build can
 * read it verbatim, which is a real exposure for a billed-per-token key.
 * Requires sign-in (same as every screen that can reach this — the app's
 * router redirects unauthenticated users to Login before they can open the
 * AI Planner or Trip Assistant at all, so this adds no new restriction).
 *
 * Back on OpenAI after a temporary stint on Groq; the request/response
 * shape is identical (`choices[0].message.content`,
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
// A non-reasoning model on purpose: reasoning models (gpt-5*) spend part of
// the budget on hidden reasoning and ignore `temperature`, and the callers'
// token budgets here are tight (220-450 for chat), so every token should go
// to the visible answer.
const OPENAI_MODEL = 'gpt-4.1-mini';
const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

exports.aiComplete = onCall({ region: 'asia-southeast1', secrets: [openAiApiKey], timeoutSeconds: 60 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'aiComplete', 30);

  const apiKey = openAiApiKey.value();
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
    model: OPENAI_MODEL,
    messages,
    temperature: typeof temperature === 'number' ? temperature : 0.7,
    max_completion_tokens: boundedMaxTokens,
  };
  if (jsonMode) body.response_format = { type: 'json_object' };

  const response = await fetch(OPENAI_CHAT_URL, {
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
 * Reads text out of an uploaded business-permit photo via Google Cloud
 * Vision's TEXT_DETECTION — reuses `googlePlacesApiKey` (same Google Cloud
 * project as Places/Routes, just needs the Cloud Vision API enabled on it
 * too) rather than provisioning a separate secret. Purely a reading aid for
 * the admin reviewing a business application — it doesn't verify the
 * permit is real, current, or belongs to the applicant, only that *some*
 * text was found in the photo.
 *
 * Takes only `businessId` — never a client-supplied `imageUrl` — and reads
 * the permit URL itself from `businesses/{businessId}/private/permit`
 * (after verifying the caller owns that business). Two deliberate
 * consequences of that shape:
 *   1. This can't be used as a free OCR proxy against an arbitrary image —
 *      the only images it will ever read are ones already sitting in an
 *      owned business's own permit slot, which storage.rules already
 *      restricted to that owner's own upload.
 *   2. `permitOcrText` is written here via the Admin SDK (bypasses
 *      firestore.rules, which forbid the client from setting that field
 *      directly) — this function is the *only* path that field can ever be
 *      set through, so a client can never fabricate OCR output that Vision
 *      never actually produced.
 * Best-effort like the Places/Routes proxies above: no text found (a blank
 * photo, poor lighting, Vision finding nothing, or Vision/the fetch itself
 * failing) all land as a normal `{ text: '' }` result, never an error —
 * this is a reading aid, never worth blocking the owner's submission over.
 */
exports.extractPermitText = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'extractPermitText', 20);

  const { businessId } = request.data ?? {};
  if (typeof businessId !== 'string' || !businessId.trim()) {
    throw new HttpsError('invalid-argument', 'businessId is required.');
  }

  const businessRef = db.collection('businesses').doc(businessId);
  const businessSnap = await businessRef.get();
  if (!businessSnap.exists || businessSnap.data()?.ownerId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'You do not own this listing.');
  }

  const permitRef = businessRef.collection('private').doc('permit');
  const permitSnap = await permitRef.get();
  const imageUrl = permitSnap.data()?.permitUrl;
  if (typeof imageUrl !== 'string' || !imageUrl) {
    return { text: '' };
  }

  const text = await detectTextInImage(imageUrl, 'extractPermitText');
  await permitRef.set({ permitOcrText: text }, { merge: true });
  return { text };
});

/**
 * Same Vision reading aid as `extractPermitText`, for the permit photo on a
 * Business Owner *application* (`business_owner_applications/{id}`) — an
 * applicant has no `businesses` doc yet, so that function's ownership check
 * can't apply to them. Same shape and guarantees otherwise: takes only
 * `applicationId` (never an image URL), reads `permitUrl` off the caller's
 * own application, and is the only writer of that doc's `permitOcrText`.
 *
 * Also stores `permitFields` — the labelled fields `parsePermitFields`
 * could pick out of that text (business name, owner, address, permit no.,
 * validity, issuing LGU) — so the admin can check them against what the
 * applicant typed. Parsed here rather than on the client for the same
 * reason as the raw text: it must only ever reflect real Vision output.
 *
 * The valid ID photo (`idUrl`) is read in the same call, but only the
 * holder's name is kept, as `idName` — the ID's raw text carries its
 * number, birth date and more, none of which the review needs, so that
 * text is never stored or returned.
 */
exports.extractApplicationPermitText = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'extractApplicationPermitText', 20);

  const { applicationId } = request.data ?? {};
  if (typeof applicationId !== 'string' || !applicationId.trim()) {
    throw new HttpsError('invalid-argument', 'applicationId is required.');
  }

  const applicationRef = db.collection('business_owner_applications').doc(applicationId);
  const applicationSnap = await applicationRef.get();
  if (!applicationSnap.exists || applicationSnap.data()?.userId !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'This is not your application.');
  }

  const { permitUrl, idUrl } = applicationSnap.data() ?? {};
  const read = (url) =>
    typeof url === 'string' && url
      ? detectDocument(url, 'extractApplicationPermitText')
      : Promise.resolve({ text: '', boxes: [] });
  const [permit, id] = await Promise.all([read(permitUrl), read(idUrl)]);
  const text = permit.text;

  await applicationRef.set(
    { permitOcrText: text, permitFields: parsePermitFields(text, permit.boxes), idName: parseIdName(id.text) },
    { merge: true },
  );
  return { text };
});

/**
 * Reads the same fields as `extractApplicationPermitText`, but *before* the
 * application exists — so the form can show the applicant what was read off
 * their permit and ID and let them correct it before submitting. Returns
 * `{ permitFields, idName }` and stores nothing: whatever the applicant ends
 * up submitting goes into the application's own `confirmedPermitFields` /
 * `confirmedIdName`, while `extractApplicationPermitText` still writes the
 * untouched Vision reading next to it for the admin to compare against.
 *
 * There's no application doc to read the URLs from yet, so unlike the two
 * functions above this one does take them from the client — but only ever
 * reads a file in the caller's own `business_application_docs/{uid}/`
 * Storage folder (see `isOwnApplicationDocUrl`), which keeps it from being
 * a free OCR proxy against arbitrary images. Either URL may be omitted, so
 * the form can read each photo as it's uploaded.
 */
exports.readApplicationDocs = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'readApplicationDocs', 20);

  const { permitUrl, idUrl } = request.data ?? {};
  const read = (url) =>
    isOwnApplicationDocUrl(url, request.auth.uid)
      ? detectDocument(url, 'readApplicationDocs')
      : Promise.resolve({ text: '', boxes: [] });
  const [permit, id] = await Promise.all([read(permitUrl), read(idUrl)]);

  // Same as extractApplicationPermitText: only the name leaves the ID's text.
  return { permitFields: parsePermitFields(permit.text, permit.boxes), idName: parseIdName(id.text) };
});

/**
 * True only for a Firebase Storage download URL of a file under
 * `business_application_docs/{uid}/` in this project's own bucket — the one
 * place `storage.rules` lets that user (and nobody else) upload to.
 */
function isOwnApplicationDocUrl(url, uid) {
  if (typeof url !== 'string' || !url) return false;
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    return false;
  }
  if (parsed.protocol !== 'https:' || parsed.hostname !== 'firebasestorage.googleapis.com') return false;
  const match = parsed.pathname.match(/^\/v0\/b\/([^/]+)\/o\/([^/]+)$/);
  if (!match) return false;
  const project = process.env.GCLOUD_PROJECT;
  if (match[1] !== `${project}.firebasestorage.app` && match[1] !== `${project}.appspot.com`) return false;
  let objectPath;
  try {
    objectPath = decodeURIComponent(match[2]);
  } catch (_) {
    return false;
  }
  return objectPath.startsWith(`business_application_docs/${uid}/`);
}

/**
 * Shared Vision TEXT_DETECTION call behind the permit-OCR functions above.
 * Never throws — every failure mode logs under [logTag] and returns ''.
 */
async function detectTextInImage(imageUrl, logTag) {
  return (await detectDocument(imageUrl, logTag)).text;
}

/**
 * [detectTextInImage] plus where each line of that text sits on the photo
 * (`boxes`, see `linesFromVision`) — what `parsePermitFields` needs to tell
 * which value belongs to which label on a multi-column permit. Never
 * throws; a failure is `{ text: '', boxes: [] }`.
 */
async function detectDocument(imageUrl, logTag) {
  const nothing = { text: '', boxes: [] };
  const apiKey = googlePlacesApiKey.value();
  if (!apiKey) return nothing;
  try {
    const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [
          {
            image: { source: { imageUri: imageUrl } },
            features: [{ type: 'TEXT_DETECTION' }],
          },
        ],
      }),
    });
    if (response.status !== 200) {
      console.error(`${logTag}: Vision API returned`, response.status, await response.text().catch(() => ''));
      return nothing;
    }
    const json = await response.json().catch(() => null);
    const result = json?.responses?.[0];
    // A per-image error (e.g. Vision couldn't fetch imageUrl) lands
    // inside a 200 response, not as an HTTP error status.
    if (result?.error) {
      console.error(`${logTag}: Vision per-image error`, result.error);
      return nothing;
    }
    const annotation = result?.fullTextAnnotation;
    return { text: annotation?.text ?? '', boxes: linesFromVision(annotation) };
  } catch (e) {
    console.error(`${logTag}: request failed`, e);
    return nothing;
  }
}

/**
 * Turns a dropped map pin's coordinates into a readable place name (plus
 * its country code, so the client can reject a pin outside the Philippines
 * — see `MapDestinationPicker`), for the manual "Create Your Own Itinerary"
 * flow's interactive map picker — reuses `googlePlacesApiKey` (same
 * project, now also enabled for the Geocoding API) rather than a separate
 * secret. Best-effort like every other Google-API proxy in this file: any
 * failure (no network, no result at that point, service down) is a normal
 * `{ name: '' }`, letting the client fall back to a plain "Pinned location"
 * label instead of blocking the traveler from using the pin they just
 * dropped.
 */
exports.reverseGeocode = onCall({ region: 'asia-southeast1', secrets: [googlePlacesApiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  await enforceRateLimit(request.auth.uid, 'reverseGeocode', 30);

  const { latitude, longitude } = request.data ?? {};
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    throw new HttpsError('invalid-argument', 'latitude and longitude are required.');
  }

  const apiKey = googlePlacesApiKey.value();
  if (!apiKey) return { name: '' };

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}`,
    );
    if (response.status !== 200) {
      console.error('reverseGeocode: Geocoding API returned', response.status, await response.text().catch(() => ''));
      return { name: '' };
    }
    const json = await response.json().catch(() => null);
    if (json?.status !== 'OK') return { name: '' };
    const result = json?.results?.[0];
    const address = result?.formatted_address ?? '';
    // Remote pins with no street address resolve to a leading Open Location
    // Code ("H6CF+R8 Balbalan, Kalinga, Philippines") — meaningless to a
    // traveler, so strip it and keep the readable part after it.
    const stripped = address.replace(/^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}[,\s]+/, '');
    // This app is Philippines-only, so the client uses this to reject a pin
    // dropped outside it — read from Google's own address component rather
    // than string-matching "Philippines" in the formatted address, which
    // isn't guaranteed to appear (or be spelled the same way) in every
    // locale/result shape.
    const countryComponent = (result?.address_components ?? []).find((c) => c.types?.includes('country'));
    return { name: stripped || address, countryCode: countryComponent?.short_name ?? '' };
  } catch (e) {
    console.error('reverseGeocode: request failed', e);
    return { name: '' };
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
 * — personal (`userId` set, including the ones `deliverProvinceAnnouncement`
 * below writes) or broadcast (`userId` == '', see
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

// Firestore's `in` filter takes at most 30 values.
const IN_QUERY_SIZE = 30;
// A write batch takes at most 500 operations.
const WRITE_BATCH_SIZE = 500;

/**
 * The travelers an LGU's announcement about [provinceId] is for: anyone
 * with a favorite on one of that province's listings, or a saved trip
 * (their own, or one they joined) headed to the province or one of its
 * tourist spots. Worked out here at send time from what travelers already
 * have saved, so there's no per-traveler "home province" to keep in sync.
 */
async function travelersInterestedInProvince(provinceId, provinceName) {
  // Which favorite `itemType` points at which collection.
  const collections = {
    destination: 'tourist_spots',
    restaurant: 'restaurants',
    festival: 'festivals',
    business: 'businesses',
  };
  const idsByType = {};
  const spotNames = [];
  await Promise.all(
    Object.entries(collections).map(async ([type, collection]) => {
      const snapshot = await db.collection(collection).where('provinceId', '==', provinceId).select('name').get();
      idsByType[type] = new Set(snapshot.docs.map((doc) => doc.id));
      if (type === 'destination') {
        for (const doc of snapshot.docs) {
          if (doc.data().name) spotNames.push(doc.data().name);
        }
      }
    }),
  );

  const uids = new Set();

  const itemIds = [...new Set(Object.values(idsByType).flatMap((ids) => [...ids]))];
  await Promise.all(
    chunk(itemIds, IN_QUERY_SIZE).map(async (ids) => {
      const snapshot = await db.collection('favorites').where('itemId', 'in', ids).select('userId', 'itemType', 'itemId').get();
      for (const doc of snapshot.docs) {
        const { userId, itemType, itemId } = doc.data();
        // The same id under another type is some other listing entirely.
        if (userId && idsByType[itemType]?.has(itemId)) uids.add(userId);
      }
    }),
  );

  const addTripMembers = (snapshot) => {
    for (const doc of snapshot.docs) {
      const { userId, collaboratorIds } = doc.data();
      if (userId) uids.add(userId);
      if (Array.isArray(collaboratorIds)) collaboratorIds.forEach((uid) => uids.add(uid));
    }
  };
  const trips = db.collection('saved_itineraries');
  // A trip names its destination by tourist-spot id when it has one, and
  // always by name — the province's own name for a whole-province trip.
  const destinationNames = [...new Set([provinceName, ...spotNames].filter(Boolean))];
  await Promise.all([
    ...chunk([...idsByType.destination], IN_QUERY_SIZE).map(async (ids) =>
      addTripMembers(await trips.where('itinerary.destinationId', 'in', ids).select('userId', 'collaboratorIds').get()),
    ),
    ...chunk(destinationNames, IN_QUERY_SIZE).map(async (names) =>
      addTripMembers(await trips.where('itinerary.destinationName', 'in', names).select('userId', 'collaboratorIds').get()),
    ),
  ]);

  return [...uids];
}

/**
 * An LGU account's "Send Announcement" (see
 * `NotificationRepository.createProvinceAnnouncement`) — delivered as one
 * personal `notifications` doc per interested traveler rather than a
 * nationwide broadcast, so it shows up in only their bell. Each of those
 * docs then goes out as a push through `sendPushOnNotificationCreated`
 * above, exactly like any other personal notification.
 */
exports.deliverProvinceAnnouncement = onDocumentCreated('province_announcements/{announcementId}', async (event) => {
  const announcement = event.data?.data();
  if (!announcement) return;

  const { provinceId, provinceName, title, body, category } = announcement;
  if (!provinceId || !title || !body) return;

  const uids = await travelersInterestedInProvince(provinceId, provinceName ?? '');

  for (const batchUids of chunk(uids, WRITE_BATCH_SIZE)) {
    const batch = db.batch();
    for (const uid of batchUids) {
      // Keyed by announcement + traveler, so a retried delivery overwrites
      // its own notification instead of sending the traveler a second one.
      batch.set(db.collection('notifications').doc(`${event.params.announcementId}_${uid}`), {
        userId: uid,
        title,
        body,
        category: category ?? 'general',
        createdAt: FieldValue.serverTimestamp(),
        isRead: false,
        relatedId: null,
        imageUrl: '',
        provinceId,
      });
    }
    await batch.commit();
  }

  await event.data.ref.update({ recipientCount: uids.length, deliveredAt: FieldValue.serverTimestamp() });
});

/**
 * A "Travelers say..." summary generated from a listing's own review text —
 * refreshed on a schedule (never on-demand from the app), so opening a
 * details page is never what triggers a billed OpenAI call. Restaurants only
 * for now: they're the one review target type with enough real review
 * volume in this app to make a summary worth the API cost.
 */
const REVIEW_DIGEST_MIN_REVIEWS = 3;
// A digest is only worth regenerating once enough new reviews have come in
// since the last one — otherwise every run would spend an OpenAI call on every
// popular listing for a summary that would barely have changed.
const REVIEW_DIGEST_MIN_NEW_REVIEWS = 3;

/**
 * Same OpenAI chat-completions endpoint `aiComplete` proxies, called directly
 * here instead of through it — `aiComplete` is a client-facing callable with
 * its own auth/rate-limit/argument-validation wrapper that makes no sense
 * for a server-triggered scheduled job, so this is a separate, minimal path
 * to the same upstream API rather than a refactor of that tested function.
 */
async function summarizeReviews(apiKey, placeName, comments) {
  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      temperature: 0.4,
      max_completion_tokens: 220,
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
    throw new Error(`OpenAI request failed (${response.status}): ${json?.error?.message ?? 'unknown error'}`);
  }
  const json = await response.json();
  const content = json?.choices?.[0]?.message?.content;
  if (!content || !content.trim()) throw new Error('OpenAI returned an empty response.');
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
  { region: 'asia-southeast1', schedule: 'every 24 hours', secrets: [openAiApiKey], timeoutSeconds: 540 },
  async () => {
    const apiKey = openAiApiKey.value();
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
        // Best-effort — one bad listing (a transient OpenAI error, say)
        // shouldn't stop the rest of this run from generating theirs.
        console.error(`generateReviewDigests: failed for restaurants/${doc.id}`, e);
      }
    }
  },
);
