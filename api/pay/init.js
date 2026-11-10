// POST /api/pay/init  { plan, name, email, phone, promo }  ->  { url }  (SSLCommerz hosted checkout)
const crypto = require('crypto');
const { PLANS, gatewayHost, configured, promoPercent, origin, sign } = require('../_lib/pay');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Use POST.' });
  if (!configured()) return res.status(503).json({ error: 'Online payment isn’t switched on yet. Nothing was charged; please try again soon.' });

  const b = req.body || {};
  const plan = PLANS[b.plan];
  const name = String(b.name || '').trim().slice(0, 80);
  const email = String(b.email || '').trim().toLowerCase().slice(0, 120);
  const phone = String(b.phone || '').replace(/[\s-]/g, '').replace(/^\+?88/, '');
  if (!plan) return res.status(400).json({ error: 'Choose a plan.' });
  if (name.length < 2) return res.status(400).json({ error: 'Enter your full name.' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ error: 'Enter a valid email.' });
  if (!/^01[3-9]\d{8}$/.test(phone)) return res.status(400).json({ error: 'Enter an 11-digit Bangladeshi number.' });

  const pct = promoPercent(String(b.promo || '').trim());
  if (pct < 0) return res.status(400).json({ error: 'That promo code isn’t valid.' });
  const amount = Math.max(10, Math.round(plan.amount * (100 - pct) / 100)); // SSLCommerz minimum is ৳10
  const tranId = `SB${Date.now().toString(36).toUpperCase()}${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
  const base = origin(req);

  const form = new URLSearchParams({
    store_id: process.env.SSLCZ_STORE_ID, store_passwd: process.env.SSLCZ_STORE_PASSWD,
    total_amount: amount.toFixed(2), currency: 'BDT', tran_id: tranId,
    success_url: `${base}/api/pay/return`, fail_url: `${base}/api/pay/return`, cancel_url: `${base}/api/pay/return`,
    ipn_url: `${base}/api/pay/ipn`,
    cus_name: name, cus_email: email, cus_phone: phone,
    cus_add1: 'Bangladesh', cus_city: 'Dhaka', cus_postcode: '1000', cus_country: 'Bangladesh',
    shipping_method: 'NO', num_of_item: '1',
    product_name: `Stashbar ${plan.name}`, product_category: 'Software', product_profile: 'non-physical-goods',
    value_a: b.plan, value_b: email, value_c: sign(`${tranId}|${b.plan}|${amount}`), value_d: String(amount),
  });

  try {
    const r = await fetch(`${gatewayHost()}/gwprocess/v4/api.php`, { method: 'POST', body: form });
    const data = await r.json();
    if (data.status === 'SUCCESS' && data.GatewayPageURL) return res.status(200).json({ url: data.GatewayPageURL, ref: tranId });
    console.error('SSLCommerz init failed', data.failedreason || data);
    return res.status(502).json({ error: 'Checkout couldn’t open. Nothing was charged; please try again.' });
  } catch (e) {
    console.error('SSLCommerz init error', e);
    return res.status(502).json({ error: 'Checkout couldn’t open. Nothing was charged; please try again.' });
  }
};
