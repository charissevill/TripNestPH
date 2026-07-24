// Seeds Firestore with the Phase 1 mock content (tourist_spots,
// restaurants, festivals, travel_tips) via the Firestore REST API,
// authenticated with the Firebase CLI's own OAuth session (which has
// Editor/Owner IAM rights on the project and so bypasses the security
// rules — exactly the "admin" path a real seed script needs).
//
// Usage:
//   dart run tool/export_seed_data.dart > tool/seed_data.json
//   node tool/seed_firestore.js
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT_ID = 'tripnest-ph';
const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const token = cfg.tokens.access_token;

const seedDataPath = path.join(__dirname, 'seed_data.json');
const seedData = JSON.parse(fs.readFileSync(seedDataPath, 'utf8'));

const travelTips = {
  'tip-1': {
    title: 'Best time to visit',
    description: 'Plan trips between November and May to avoid the rainy season and enjoy the sunniest island weather.',
    iconKey: 'wb_sunny',
    colorKey: 'accent',
  },
  'tip-2': {
    title: 'Carry small bills',
    description: 'Jeepneys, tricycles and market stalls rarely have change for large bills — keep ₱20–₱100 notes handy.',
    iconKey: 'payments',
    colorKey: 'secondary',
  },
  'tip-3': {
    title: 'Island hopping tip',
    description: 'Book boat transfers a day ahead during peak season (March–May) — popular routes fill up fast.',
    iconKey: 'directions_boat',
    colorKey: 'primary',
  },
  'tip-4': {
    title: 'Respect local customs',
    description: 'Dress modestly when visiting churches and heritage sites, and always ask before photographing locals.',
    iconKey: 'diversity_3',
    colorKey: 'secondaryDark',
  },
  'tip-5': {
    title: 'Stay connected',
    description: 'Grab a local SIM at the airport — Globe and Smart both offer affordable tourist data packs.',
    iconKey: 'sim_card',
    colorKey: 'primaryDark',
  },
};

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: toFirestoreFields(value) } };
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

async function upsertDocument(collection, docId, data) {
  const fields = toFirestoreFields(data);
  const reqPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
  const res = await request('PATCH', 'firestore.googleapis.com', reqPath, { fields });
  if (res.status >= 200 && res.status < 300) {
    console.log(`  ok   ${collection}/${docId}`);
  } else {
    console.error(`  FAIL ${collection}/${docId} -> ${res.status}: ${res.body}`);
  }
  return res.status < 300;
}

async function seedCollection(collection, docs) {
  console.log(`Seeding ${collection} (${Object.keys(docs).length} docs)...`);
  let ok = 0;
  for (const [docId, data] of Object.entries(docs)) {
    const success = await upsertDocument(collection, docId, data);
    if (success) ok += 1;
  }
  console.log(`Done: ${ok}/${Object.keys(docs).length} succeeded.\n`);
}

(async () => {
  // Geography first — tourist_spots/restaurants/festivals reference
  // provinceId/regionId, so seeding order doesn't matter for Firestore
  // itself (no foreign-key enforcement), but running these first makes the
  // console output easier to read top-to-bottom by dependency.
  await seedCollection('regions', seedData.regions);
  await seedCollection('provinces', seedData.provinces);
  await seedCollection('tourist_spots', seedData.tourist_spots);
  await seedCollection('restaurants', seedData.restaurants);
  await seedCollection('festivals', seedData.festivals);
  await seedCollection('travel_tips', travelTips);
})();
