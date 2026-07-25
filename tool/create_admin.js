// One-time bootstrap: grants an existing Firebase Auth user Admin Portal
// access by creating their admin_users/{uid} doc, authenticated with the
// Firebase CLI's own OAuth session — the same out-of-band, rules-bypassing
// path tool/seed_firestore.js already uses, and the only way to create the
// very first admin_users doc (every other write to that collection requires
// hasAdminRole(['admin']) in firestore.rules, which nothing can satisfy
// until this script runs once).
//
// Usage:
//   node tool/create_admin.js someone@example.com [role] [name]
//
// [role] defaults to 'admin' (admin, lgu or businessOwner — see AdminRole
// in lib/domain/models/admin_user.dart). 'admin' also covers
// every lgu-only permission, so it's the right default for a solo owner
// account.
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT_ID = 'tripnest-ph';
const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const token = cfg.tokens.access_token;

const email = process.argv[2];
const role = process.argv[3] || 'admin';
const name = process.argv[4] || '';

if (!email) {
  console.error('Usage: node tool/create_admin.js <email> [role] [name]');
  process.exit(1);
}

function request(method, hostname, reqPath, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const options = {
      hostname,
      path: reqPath,
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    };
    if (data) options.headers['Content-Length'] = Buffer.byteLength(data);
    const req = https.request(options, (res) => {
      let out = '';
      res.on('data', (c) => (out += c));
      res.on('end', () => resolve({ status: res.statusCode, body: out }));
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  throw new Error(`Unsupported value type: ${typeof value}`);
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

async function getUidByEmail(targetEmail) {
  const res = await request(
    'POST',
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:lookup`,
    { email: [targetEmail] },
  );
  if (res.status !== 200) {
    throw new Error(`Auth lookup failed (${res.status}): ${res.body}`);
  }
  const body = JSON.parse(res.body);
  if (!body.users || body.users.length === 0) {
    throw new Error(`No Firebase Auth user found for ${targetEmail} — they need to sign up in the app first.`);
  }
  return body.users[0].localId;
}

(async () => {
  console.log(`Looking up Firebase Auth user for ${email}...`);
  const uid = await getUidByEmail(email);
  console.log(`Found uid: ${uid}`);

  const fields = toFirestoreFields({
    name: name || email,
    email,
    photoUrl: '',
    businessName: '',
    role,
    status: 'active',
  });

  const reqPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/admin_users/${uid}`;
  const res = await request('PATCH', 'firestore.googleapis.com', reqPath, { fields });
  if (res.status >= 200 && res.status < 300) {
    console.log(`\nDone — admin_users/${uid} created with role "${role}".`);
    console.log('Open Profile in the app (may need a moment to sync) and "Admin Portal" should now appear.');
  } else {
    console.error(`FAIL admin_users/${uid} -> ${res.status}: ${res.body}`);
    process.exit(1);
  }
})();
