The payment was declined at commit time — the held args
carried {{ payment_id }} the env rejected. Release the hold
(release(held: ...)), re-check it against {{ payment_methods }},
and hold again.
