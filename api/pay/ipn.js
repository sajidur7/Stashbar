// SSLCommerz's server-to-server notification (IPN). Records the payment even if the buyer
// closes the tab before being redirected back.
const { validate, recordPayment } = require('../_lib/pay');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).end();
  const b = req.body || {};
  if (b.status !== 'VALID' || !b.val_id) return res.status(200).json({ ok: true, ignored: b.status || 'none' });
  try {
    const p = await validate(String(b.val_id));
    if (!p) return res.status(400).json({ ok: false });
    await recordPayment(p);
    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('IPN failed', e);
    return res.status(500).json({ ok: false }); // SSLCommerz retries
  }
};
