// Shared payment helpers for the Vercel functions in /api/pay.
// Secrets come only from Vercel environment variables, never from the browser:
//   SSLCZ_STORE_ID, SSLCZ_STORE_PASSWD   SSLCommerz store credentials
//   SSLCZ_LIVE=1                         use the live gateway (sandbox otherwise)
//   FIREBASE_SERVICE_ACCOUNT             service-account JSON, to record paid plans in Firestore
//   PROMO_CODES                          optional, e.g. "LAUNCH20:20,FRIENDS:50" (code:percent off)
const crypto = require('crypto');

// Prices are decided here, on the server, so the browser can't change them.
const PLANS = {
  monthly: { name: 'Monthly', amount: { BDT: 499, USD: 4.99 }, days: 30 },
  lifetime: { name: 'Lifetime', amount: { BDT: 999, USD: 9.99 }, days: null },
};

const gatewayHost = () => (process.env.SSLCZ_LIVE === '1' ? 'https://securepay.sslcommerz.com' : 'https://sandbox.sslcommerz.com');
const configured = () => Boolean(process.env.SSLCZ_STORE_ID && process.env.SSLCZ_STORE_PASSWD);

function promoPercent(code) {
  if (!code) return 0;
  for (const entry of (process.env.PROMO_CODES || '').split(',')) {
    const [c, pct] = entry.split(':').map(s => (s || '').trim());
    if (c && c.toUpperCase() === code.toUpperCase()) return Math.min(100, Math.max(0, Number(pct) || 0));
  }
  return -1; // unknown code
}

function origin(req) {
  const proto = req.headers['x-forwarded-proto'] || 'https';
  return `${proto}://${req.headers['x-forwarded-host'] || req.headers.host}`;
}

// Ask SSLCommerz whether a payment really went through. Never trust the browser's redirect alone.
async function validate(valId) {
  const q = new URLSearchParams({ val_id: valId, store_id: process.env.SSLCZ_STORE_ID, store_passwd: process.env.SSLCZ_STORE_PASSWD, format: 'json' });
  const r = await fetch(`${gatewayHost()}/validator/api/validationserverAPI.php?${q}`);
  const v = await r.json();
  if (v.status !== 'VALID' && v.status !== 'VALIDATED') return null;
  const plan = PLANS[v.value_a];
  const [cur, amt] = String(v.value_d || '').split(':'); // the currency and discounted amount we asked for, signed below
  if (!plan || v.currency_type !== cur) return null;
  const paid = Number(v.currency_amount);
  const expected = Number(amt);
  if (!(paid >= expected - 0.01) || sign(`${v.tran_id}|${v.value_a}|${v.value_d}`) !== v.value_c) return null;
  return { tranId: v.tran_id, plan: v.value_a, email: (v.value_b || '').toLowerCase(), amount: paid, currency: cur, valId, bankTranId: v.bank_tran_id || '', cardType: v.card_type || '' };
}

// HMAC so a tampered plan/amount in the round trip is detected.
function sign(s) {
  return crypto.createHmac('sha256', process.env.SSLCZ_STORE_PASSWD || 'unset').update(s).digest('hex').slice(0, 32);
}

// ---- Firestore (service account, REST) ----
let cachedToken = null;
async function googleToken() {
  if (cachedToken && cachedToken.exp > Date.now() + 60_000) return cachedToken;
  const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);
  const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/datastore', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })}`;
  const jwt = `${unsigned}.${crypto.createSign('RSA-SHA256').update(unsigned).sign(sa.private_key, 'base64url')}`;
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }) });
  const t = await r.json();
  if (!t.access_token) throw new Error('Service account token failed');
  cachedToken = { token: t.access_token, project: sa.project_id, exp: Date.now() + t.expires_in * 1000 };
  return cachedToken;
}

const fsValue = v => (v === null ? { nullValue: null } : typeof v === 'number' ? { doubleValue: v } : v instanceof Date ? { timestampValue: v.toISOString() } : { stringValue: String(v) });
async function fsSet(path, data) {
  const { token, project } = await googleToken();
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, fsValue(v)]));
  const r = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}`, { method: 'PATCH', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ fields }) });
  if (!r.ok) throw new Error(`Firestore write failed: ${r.status}`);
}

// Record a confirmed payment and switch the plan on for that email. Safe to call twice (IPN + return).
async function recordPayment(p) {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) { console.warn('FIREBASE_SERVICE_ACCOUNT not set; payment not recorded', p.tranId); return; }
  const plan = PLANS[p.plan];
  const now = new Date();
  await fsSet(`payments/${p.tranId}`, { ...p, provider: 'sslcommerz', createdAt: now });
  await fsSet(`entitlements/${p.email.replace(/\//g, "_")}`, {
    plan: p.plan, email: p.email, tranId: p.tranId, updatedAt: now,
    expiresAt: plan.days ? new Date(now.getTime() + plan.days * 864e5) : null,
  });
}

module.exports = { PLANS, gatewayHost, configured, promoPercent, origin, validate, sign, recordPayment };
