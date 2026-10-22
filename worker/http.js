// Small helpers shared by the Cloudflare functions.

export const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });

/** The signed-in Supabase user making the request, or null. Only the owner's account is accepted. */
export async function owner(request, env) {
  const token = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token || !env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) return null;
  const r = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, Authorization: `Bearer ${token}` },
  });
  if (!r.ok) return null;
  const user = await r.json();
  return env.OWNER_USER_ID && user.id !== env.OWNER_USER_ID ? null : user;
}

/** Compares two secrets without leaking how many characters matched. */
export function sameSecret(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Headers for writing to Supabase with the secret key (only ever used inside the Worker). */
export function adminHeaders(env, extra = {}) {
  const h = { apikey: env.SUPABASE_SECRET_KEY, 'content-type': 'application/json', ...extra };
  if (env.SUPABASE_SECRET_KEY.startsWith('eyJ')) h.Authorization = `Bearer ${env.SUPABASE_SECRET_KEY}`; // older "service_role" keys
  return h;
}

/** Reads the Shortcut's JSON and checks its key (HEALTH_KEY), sent either as the header
    "Authorization: Bearer <key>" or as a "key" field in the JSON.
    The whole body is always read before answering: if the server replies while the iPhone is still
    sending, iOS reports "La connexion réseau a été perdue" instead of the real error.
    Returns { body } when it's fine, or { error: Response }. */
export async function readShortcut(request, env) {
  const raw = await request.text();
  let body = null;
  try { body = JSON.parse(raw); } catch { /* checked below */ }
  const header = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();
  const field = String(body?.key ?? '').replace(/^Bearer\s+/i, '').trim();
  const expected = (env.HEALTH_KEY || '').trim();
  if (!expected) return { error: json({ error: 'HEALTH_KEY is not set in Cloudflare' }, 500) };
  if (!sameSecret(header, expected) && !sameSecret(field, expected)) {
    const key = field || header;
    // Saying how long the received and stored keys are (never what they are) makes a bad paste easy to spot.
    return { error: json({ error: 'wrong key', receivedLength: key.length, expectedLength: expected.length }, 401) };
  }
  if (!env.OWNER_USER_ID || !env.SUPABASE_URL || !env.SUPABASE_SECRET_KEY) return { error: json({ error: 'not configured' }, 500) };
  if (!body || typeof body !== 'object') return { error: json({ error: 'send JSON' }, 400) };
  return { body };
}
