// SSLCommerz sends the buyer back here (POST) after success, failure or cancel.
// We confirm with SSLCommerz's validation API before showing success, then redirect to /pay/done.
const { validate, recordPayment } = require('../_lib/pay');

module.exports = async (req, res) => {
  const b = req.body || req.query || {};
  const go = (q) => { res.statusCode = 303; res.setHeader('Location', `/pay/done?${new URLSearchParams(q)}`); res.end(); };
  const ref = String(b.tran_id || '');
  if (b.status === 'CANCELLED') return go({ s: 'cancel', ref });
  if (b.status !== 'VALID' || !b.val_id) return go({ s: 'fail', ref });
  try {
    const p = await validate(String(b.val_id));
    if (!p) return go({ s: 'fail', ref });
    await recordPayment(p);
    return go({ s: 'ok', ref: p.tranId, plan: p.plan });
  } catch (e) {
    console.error('Return handling failed', e);
    // The payment may still be fine; the IPN call records it independently.
    return go({ s: 'check', ref });
  }
};
