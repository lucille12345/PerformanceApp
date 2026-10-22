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

/** Checks the Shortcut's key (HEALTH_KEY). Returns an error response, or null when it's fine. */
export function checkShortcutKey(request, env) {
  const key = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '').trim();
  const expected = (env.HEALTH_KEY || '').trim();
  if (!expected) return json({ error: 'HEALTH_KEY is not set in Cloudflare' }, 500);
  if (!sameSecret(key, expected)) {
    // Saying how long the stored key is (never what it is) makes a bad paste easy to spot.
    return json({ error: 'unauthorized', ...(key.length !== expected.length && { storedKeyLength: expected.length }) }, 401);
  }
  if (!env.OWNER_USER_ID || !env.SUPABASE_URL || !env.SUPABASE_SECRET_KEY) return json({ error: 'not configured' }, 500);
  return null;
}
