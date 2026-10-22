/* POST /api/health — called once a night by the iPhone Shortcut with the day's Santé numbers.
   Header:  Authorization: Bearer <HEALTH_KEY>
   Body:    { "day": "2026-10-21", "steps": 8412, "distance": 6.1, "energy": 412,
              "resting_hr": 58, "sleep": 7.2, "flights": 9 }
   Every field is optional; numbers may arrive as text ("8 412", "6,1"). Sending the same day
   again just replaces it. */
import { json, sameSecret } from '../../lib/http.js';

const num = (v) => {
  if (v == null || v === '') return null;
  const n = Number(String(v).replace(/[\s  ]/g, '').replace(',', '.').replace(/[^\d.-]/g, ''));
  return Number.isFinite(n) ? n : null;
};

/** Sleep can arrive in hours, minutes or seconds depending on how the Shortcut adds it up. */
const hours = (v) => (v == null ? null : v > 1440 ? v / 3600 : v > 24 ? v / 60 : v);

export async function onRequestPost({ request, env }) {
  const key = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!sameSecret(key, env.HEALTH_KEY || '')) return json({ error: 'unauthorized' }, 401);
  if (!env.OWNER_USER_ID || !env.SUPABASE_URL || !env.SUPABASE_SECRET_KEY) return json({ error: 'not configured' }, 500);

  let b;
  try { b = await request.json(); } catch { return json({ error: 'send JSON' }, 400); }

  // Default: yesterday, in your time zone.
  const yesterday = new Intl.DateTimeFormat('en-CA', { timeZone: env.TIMEZONE || 'Europe/Paris' }).format(Date.now() - 864e5);
  const day = /^\d{4}-\d{2}-\d{2}$/.test(String(b.day || '').trim()) ? String(b.day).trim() : yesterday;

  const row = {
    user_id: env.OWNER_USER_ID, day,
    steps: num(b.steps), distance_km: num(b.distance), active_kcal: num(b.energy),
    resting_hr: num(b.resting_hr), sleep_h: hours(num(b.sleep)), flights: num(b.flights),
    updated_at: new Date().toISOString(),
  };

  const headers = { apikey: env.SUPABASE_SECRET_KEY, 'content-type': 'application/json', Prefer: 'resolution=merge-duplicates' };
  if (env.SUPABASE_SECRET_KEY.startsWith('eyJ')) headers.Authorization = `Bearer ${env.SUPABASE_SECRET_KEY}`; // older "service_role" keys
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/perf_health?on_conflict=user_id,day`, { method: 'POST', headers, body: JSON.stringify(row) });
  if (!r.ok) return json({ error: 'could not save', detail: await r.text() }, 502);
  return json({ saved: day });
}
