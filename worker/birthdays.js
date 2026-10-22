/* POST /api/birthdays — called by the iPhone Shortcut with every birthday in Contacts.
   Header:  Authorization: Bearer <HEALTH_KEY>
   Body:    { "list": "Marie Dupont|1998-03-14\nPaul|03-02\n…" }   one person per line, "Name|date"
            Dates can be 1998-03-14, 03-14, 14/03/1998 or 14/03. The list replaces the previous one. */
import { adminHeaders, checkShortcutKey, json } from './http.js';

function parseDate(s) {
  const t = String(s).trim();
  let m;
  if ((m = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/))) return { year: +m[1], month: +m[2], day: +m[3] };
  if ((m = t.match(/^-{0,2}(\d{1,2})-(\d{1,2})$/))) return { year: null, month: +m[1], day: +m[2] };
  if ((m = t.match(/^(\d{1,2})[/.](\d{1,2})(?:[/.](\d{4}))?/))) return { year: m[3] ? +m[3] : null, month: +m[2], day: +m[1] };
  return null;
}

export async function onRequestPost({ request, env }) {
  const denied = checkShortcutKey(request, env);
  if (denied) return denied;

  let b;
  try { b = await request.json(); } catch { return json({ error: 'send JSON' }, 400); }
  const lines = Array.isArray(b.list) ? b.list : String(b.list ?? '').split(/\r?\n/);

  const rows = new Map();
  for (const line of lines.slice(0, 5000)) {
    const [name, date] = String(line).split('|');
    const d = date && parseDate(date);
    if (!name?.trim() || !d || d.month < 1 || d.month > 12 || d.day < 1 || d.day > 31) continue;
    // iOS stores "no year" birthdays as 1604; treat anything that old as unknown.
    const year = d.year && d.year >= 1900 && d.year <= new Date().getFullYear() ? d.year : null;
    const row = { user_id: env.OWNER_USER_ID, name: name.trim().slice(0, 120), month: d.month, day: d.day, year, updated_at: new Date().toISOString() };
    rows.set(`${row.name}|${row.month}|${row.day}`, row);
  }
  if (!rows.size) return json({ error: 'no birthdays found in the list' }, 400);

  const base = `${env.SUPABASE_URL}/rest/v1/perf_birthdays`;
  const del = await fetch(`${base}?user_id=eq.${env.OWNER_USER_ID}`, { method: 'DELETE', headers: adminHeaders(env) });
  if (!del.ok) return json({ error: 'could not save', detail: await del.text() }, 502);
  const ins = await fetch(`${base}?on_conflict=user_id,name,month,day`, {
    method: 'POST', headers: adminHeaders(env, { Prefer: 'resolution=merge-duplicates' }), body: JSON.stringify([...rows.values()]),
  });
  if (!ins.ok) return json({ error: 'could not save', detail: await ins.text() }, 502);
  return json({ saved: rows.size });
}
