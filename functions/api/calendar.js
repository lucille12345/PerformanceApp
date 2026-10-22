/* GET /api/calendar?from=<ms>&to=<ms>&day=YYYY-MM-DD
   Today's events from the calendar links in the CALENDAR_URLS setting
   (iCloud "Public Calendar" or Google "Secret address in iCal format").
   Only the owner's signed-in account can call it. */
import ICAL from 'ical.js';
import { json, owner } from '../../lib/http.js';

export async function onRequestGet({ request, env }) {
  if (!(await owner(request, env))) return json({ error: 'unauthorized' }, 401);
  const q = new URL(request.url).searchParams;
  const from = Number(q.get('from')), to = Number(q.get('to')), day = q.get('day') || '';
  if (!from || !to || to <= from || !/^\d{4}-\d{2}-\d{2}$/.test(day)) return json({ error: 'bad request' }, 400);

  const urls = (env.CALENDAR_URLS || '').split(/[\s,]+/).filter(Boolean).map((u) => u.replace(/^webcals?:\/\//i, 'https://'));
  const lists = await Promise.all(urls.map((u) => eventsFrom(u, from, to, day).catch(() => [])));
  const events = lists.flat().sort((a, b) => (b.allDay - a.allDay) || a.start - b.start);
  return json({ events });
}

async function eventsFrom(url, from, to, day) {
  // Cloudflare keeps the downloaded calendar for 5 minutes, so opening the app stays fast.
  const r = await fetch(url, { cf: { cacheTtl: 300, cacheEverything: true } });
  if (!r.ok) throw new Error(`calendar ${r.status}`);
  const cal = new ICAL.Component(ICAL.parse(await r.text()));
  for (const tz of cal.getAllSubcomponents('vtimezone')) ICAL.TimezoneService.register(tz);

  const rawColor = cal.getFirstPropertyValue('x-apple-calendar-color') || '';
  const color = /^#[0-9a-f]{3,8}$/i.test(rawColor) ? rawColor : null;

  // Recurring events: the main event plus its edited occurrences.
  const masters = new Map(), edits = [];
  for (const v of cal.getAllSubcomponents('vevent')) {
    if (v.hasProperty('recurrence-id')) edits.push(v);
    else masters.set(v.getFirstPropertyValue('uid'), new ICAL.Event(v));
  }
  for (const v of edits) masters.get(v.getFirstPropertyValue('uid'))?.relateException(v);

  const out = [];
  const add = (item, start, end) => {
    if (String(item.component.getFirstPropertyValue('status') || '').toUpperCase() === 'CANCELLED') return;
    const title = item.summary || '';
    if (start.isDate) {
      const s = start.toString().slice(0, 10), e = end ? end.toString().slice(0, 10) : s;
      if (s === day || (s <= day && day < e)) out.push({ title, start: from, allDay: true, color });
    } else {
      const s = start.toJSDate().getTime(), e = end ? end.toJSDate().getTime() : s;
      if (s < to && (e > from || s >= from)) out.push({ title, start: s, allDay: false, color });
    }
  };

  for (const ev of masters.values()) {
    if (!ev.isRecurring()) { add(ev, ev.startDate, ev.endDate); continue; }
    const it = ev.iterator();
    for (let next, n = 0; (next = it.next()) && n < 20000; n++) {
      const o = ev.getOccurrenceDetails(next);
      if (o.startDate.isDate ? o.startDate.toString().slice(0, 10) > day : o.startDate.toJSDate().getTime() >= to) break;
      add(o.item, o.startDate, o.endDate);
    }
  }
  return out;
}
