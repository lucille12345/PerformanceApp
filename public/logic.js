/* ============================================================================
   Performance — data rules (no UI in here)
   ----------------------------------------------------------------------------
   • An "app day" starts at 02:00: at 01:30 on Friday it's still Thursday, and
     at 02:00 every box unticks itself (yesterday's ticks stay in History).
   • Every piece of data carries a `modified` time. When two devices disagree,
     the newest change wins, so merging always ends with both identical.
   • When a month ends its statistics are frozen into a summary (kept forever);
     day-by-day detail older than KEEP_MONTHS months is then deleted.
   ============================================================================ */

export const RESET_HOUR = 2;
export const KEEP_MONTHS = 3;

// ---------- dates ----------
const pad = (n) => String(n).padStart(2, '0');

export function appDay(date = new Date()) {
  const d = new Date(date.getTime() - RESET_HOUR * 3600e3);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
export const dayKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const monthKey = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
export const monthOfDayKey = (k) => k.slice(0, 7);
export function parseDay(k) { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); }
export function parseMonth(k) { const [y, m] = k.split('-').map(Number); return new Date(y, m - 1, 1); }
export const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
export const addMonths = (d, n) => new Date(d.getFullYear(), d.getMonth() + n, 1);
export const startOfMonth = (d) => new Date(d.getFullYear(), d.getMonth(), 1);
export function startOfWeek(d) { return addDays(d, -((d.getDay() + 6) % 7)); } // Monday
export function daysInMonth(first) {
  const n = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
  return Array.from({ length: n }, (_, i) => new Date(first.getFullYear(), first.getMonth(), i + 1));
}
export const sameDay = (a, b) => dayKey(a) === dayKey(b);

export const uid = () => (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));

// ---------- formatting ----------
export const fmtHours = (min) => { const m = Math.round(min); return `${Math.floor(m / 60)}:${pad(m % 60)}`; };
export function fmtDuration(min) {
  const s = Math.round(min * 60);
  return s >= 3600 ? `${Math.floor(s / 3600)}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}` : `${Math.floor(s / 60)}:${pad(s % 60)}`;
}
export const fmtThousands = (v) => Math.round(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
export const fmtTime = (minutes) => `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;

// ---------- data shape ----------
export function emptyData() {
  return { schedule: [], days: {}, notes: {}, workouts: [], months: {}, prunedBefore: null };
}

/** An activity is either on the schedule (done by a time) or on the to-do list (takes some time). */
export const isTodo = (i) => i.kind === 'todo';

/** Schedule activities by time, then to-do activities by name. */
export const activeSchedule = (d) =>
  d.schedule.filter((i) => !i.deleted).sort((a, b) =>
    isTodo(a) - isTodo(b) || (isTodo(a) ? 0 : a.due - b.due) || a.title.localeCompare(b.title));
export const activeWorkouts = (d) => d.workouts.filter((w) => !w.deleted);

/** 45 → "45 min", 90 → "1h30", 120 → "2h" */
export function fmtSpan(min) {
  if (min == null) return '—';
  const m = Math.round(min);
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)}h${m % 60 ? pad(m % 60) : ''}`;
}

/** Reads what was typed for a time span: "45", "1:30", "1h30", "1h", "90 min" → minutes. */
export function parseSpan(text) {
  const t = String(text).trim().toLowerCase().replace(/\s+/g, '');
  let m;
  if ((m = t.match(/^(\d+)h(\d{1,2})?(?:min|m)?$/))) return Number(m[1]) * 60 + Number(m[2] || 0);
  if ((m = t.match(/^(\d+):(\d{1,2})$/))) return Number(m[1]) * 60 + Number(m[2]);
  if ((m = t.match(/^(\d+)(?:min|m)?$/))) return Number(m[1]);
  return null;
}

export const isDone = (rec, id) => rec?.ticks?.[id]?.done === true;
export const doneCount = (rec) => Object.keys(rec.items).filter((id) => isDone(rec, id)).length;
export const itemCount = (rec) => Object.keys(rec.items).length;
export const isPerfect = (rec) => !!rec && itemCount(rec) > 0 && doneCount(rec) === itemCount(rec);

function snapshot(key, schedule, ticks = {}) {
  const items = {};
  for (const i of schedule) items[i.id] = i.title;
  return { key, items, ticks };
}

// ---------- merging two devices ----------
const newer = (a, b) => ((a.modified ?? 0) >= (b.modified ?? 0) ? a : b);

function mergeByID(a, b) {
  const by = new Map();
  for (const x of [...a, ...b]) { const e = by.get(x.id); by.set(x.id, e ? newer(e, x) : x); }
  return [...by.values()].sort((x, y) => (x.id < y.id ? -1 : 1));
}
function mergeMap(a = {}, b = {}, pick = newer) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) out[k] = k in out ? pick(out[k], v) : v;
  return out;
}

export function merge(a, b) {
  return {
    schedule: mergeByID(a.schedule, b.schedule),
    workouts: mergeByID(a.workouts, b.workouts),
    notes: mergeMap(a.notes, b.notes),
    months: mergeMap(a.months, b.months),
    days: mergeMap(a.days, b.days, (x, y) => ({
      key: x.key,
      items: { ...y.items, ...x.items },
      ticks: mergeMap(x.ticks, y.ticks),
    })),
    prunedBefore: [a.prunedBefore, b.prunedBefore].filter(Boolean).sort().pop() ?? null,
  };
}

/** JSON with sorted keys, so two equal data sets always give the same text. */
export function canonical(v) {
  if (Array.isArray(v)) return `[${v.map(canonical).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).sort().filter((k) => v[k] !== undefined).map((k) => `${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`;
  return JSON.stringify(v ?? null);
}

// ---------- counts & summaries ----------
export function counts(records) {
  const done = {}, sched = {}, order = [];
  for (const r of records) {
    for (const [id, title] of Object.entries(r.items)) {
      if (!(title in sched)) { order.push(title); sched[title] = 0; done[title] = 0; }
      sched[title]++;
      if (isDone(r, id)) done[title]++;
    }
  }
  return order.map((t) => ({ title: t, done: done[t], scheduled: sched[t] }));
}

export function summarize(mKey, d) {
  const records = Object.values(d.days).filter((r) => monthOfDayKey(r.key) === mKey && itemCount(r) > 0);
  const workouts = activeWorkouts(d).filter((w) => monthKey(appDay(new Date(w.date))) === mKey);
  const activity = {};
  for (const c of counts(records)) activity[c.title] = c.done;
  return {
    key: mKey,
    ticks: records.reduce((s, r) => s + doneCount(r), 0),
    criteria: records.reduce((s, r) => s + itemCount(r), 0),
    perfectDays: records.filter(isPerfect).length,
    missedDays: records.filter((r) => !isPerfect(r)).length,
    activity,
    sports: summarizeSports(workouts),
    cardioMinutes: workouts.filter((w) => isCardio(w.sport)).reduce((s, w) => s + w.minutes, 0),
    modified: Date.now(),
  };
}

/** Keeps the data consistent; safe to run any number of times. */
export function housekeep(input, now = new Date()) {
  const d = { ...input, days: { ...input.days }, months: { ...input.months } };
  const today = appDay(now);
  const tKey = dayKey(today);
  const schedule = activeSchedule(d);

  // 1. Today's record always follows the current schedule.
  const rec = d.days[tKey];
  const snap = snapshot(tKey, schedule, rec?.ticks ?? {});
  if (itemCount(snap) === 0 && Object.keys(snap.ticks).length === 0) delete d.days[tKey];
  else d.days[tKey] = snap;

  // 2. Days the app was never opened count as missed.
  if (schedule.length) {
    const last = Object.keys(d.days).filter((k) => k < tKey).sort().pop();
    if (last) {
      for (let day = addDays(parseDay(last), 1); day < today; day = addDays(day, 1)) {
        const k = dayKey(day);
        if (!d.days[k]) d.days[k] = snapshot(k, schedule);
      }
    }
  }

  // 3. Finished months get their frozen summary.
  const current = monthKey(today);
  const withDetail = new Set([...Object.keys(d.days).map(monthOfDayKey),
    ...activeWorkouts(d).map((w) => monthKey(appDay(new Date(w.date))))]);
  for (const m of withDetail) if (m < current && !d.months[m]) d.months[m] = summarize(m, d);

  // 4. Daily detail older than KEEP_MONTHS is deleted; only the summaries remain.
  const cutoff = monthKey(addMonths(startOfMonth(today), -KEEP_MONTHS));
  const before = d.prunedBefore && d.prunedBefore > cutoff ? d.prunedBefore : cutoff;
  for (const k of Object.keys(d.days)) if (monthOfDayKey(k) < before) delete d.days[k];
  d.workouts = d.workouts.filter((w) => monthKey(appDay(new Date(w.date))) >= before);
  d.prunedBefore = before;
  return d;
}

export function streak(d, now = new Date()) {
  const today = appDay(now);
  let n = isPerfect(d.days[dayKey(today)]) ? 1 : 0;
  for (let day = addDays(today, -1); isPerfect(d.days[dayKey(day)]); day = addDays(day, -1)) n++;
  return n;
}

/** 'perfect' | 'missed' | 'today' | 'future' | 'none' */
export function status(d, day, now = new Date()) {
  const today = appDay(now);
  if (day > today) return 'future';
  const r = d.days[dayKey(day)];
  if (sameDay(day, today)) return isPerfect(r) ? 'perfect' : 'today';
  if (!r || itemCount(r) === 0) return 'none';
  return isPerfect(r) ? 'perfect' : 'missed';
}

/** Schedule completion (0–1) for a month: frozen for past months, live for the current one. */
export function completion(d, mKey, now = new Date()) {
  const s = d.months[mKey];
  if (s && s.criteria > 0) return s.ticks / s.criteria;
  if (mKey !== monthKey(appDay(now))) return null;
  const live = summarize(mKey, d);
  return live.criteria > 0 ? live.ticks / live.criteria : null;
}

// ---------- sport ----------
/** "45" → 45 min, "45:30" → 45.5, "1:05:00" → 65 */
export function parseMinutes(text) {
  const p = String(text).trim().split(':').map((s) => s.trim());
  if (!p[0] || p.some((x) => x === '' || isNaN(Number(x)))) return null;
  const n = p.map(Number);
  if (n.length === 1) return n[0];
  if (n.length === 2) return n[0] + n[1] / 60;
  if (n.length === 3) return n[0] * 60 + n[1] + n[2] / 60;
  return null;
}

/** "5:10" or "5:10/km" (pace), "2:05/100m" (swim), "27" or "27 km/h" (speed) → { kmh, style } */
export function parseSpeed(text) {
  const t = String(text || '').toLowerCase().replace(',', '.');
  if (t.includes(':')) {
    const m = t.match(/(\d+):(\d+(?:\.\d+)?)/);
    if (!m) return null;
    const secs = Number(m[1]) * 60 + Number(m[2]);
    if (!secs) return null;
    if (t.includes('100')) return { kmh: 360 / secs, style: 'per100m' };
    if (t.includes('mi')) return { kmh: (3600 / secs) * 1.609, style: 'perKm' };
    return { kmh: 3600 / secs, style: 'perKm' };
  }
  const m = t.match(/\d+(?:\.\d+)?/);
  if (!m || Number(m[0]) <= 0) return null;
  const v = Number(m[0]);
  return { kmh: t.includes('mph') ? v * 1.609 : v, style: 'speed' };
}

export function paceText(kmh, style) {
  if (style === 'speed') return { value: kmh.toFixed(1), unit: 'KM/H' };
  const s = Math.round(style === 'per100m' ? 360 / kmh : 3600 / kmh);
  return { value: `${Math.floor(s / 60)}:${pad(s % 60)}`, unit: style === 'per100m' ? '/100M' : '/KM' };
}

const CARDIO = ['run', 'jog', 'course', 'footing', 'trail', 'cycl', 'bike', 'vélo', 'velo', 'swim', 'natation', 'row', 'aviron',
  'rameur', 'hiit', 'cardio', 'skip', 'corde', 'elliptic', 'spin', 'walk', 'marche', 'hike', 'rando', 'box', 'ski', 'danse',
  'dance', 'stair', 'escalier', 'triathlon', 'cross'];
export const isCardio = (sport) => CARDIO.some((w) => sport.toLowerCase().includes(w));

export function sportName(s) {
  const t = String(s).trim();
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase();
}

/** Per-sport totals, most minutes first, with a time-weighted average speed. */
export function summarizeSports(workouts) {
  const groups = {};
  for (const w of workouts) (groups[sportName(w.sport)] ??= []).push(w);
  return Object.entries(groups).map(([name, list]) => {
    const minutes = list.reduce((s, w) => s + w.minutes, 0);
    const timed = list.map((w) => [w.minutes, parseSpeed(w.pace)]).filter(([, sp]) => sp);
    const tMin = timed.reduce((s, [m]) => s + m, 0);
    const styles = {};
    for (const [, sp] of timed) styles[sp.style] = (styles[sp.style] ?? 0) + 1;
    return {
      name, minutes, sessions: list.length,
      avgKmh: tMin > 0 ? timed.reduce((s, [m, sp]) => s + m * sp.kmh, 0) / tMin : null,
      style: Object.entries(styles).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'speed',
    };
  }).sort((a, b) => b.minutes - a.minutes);
}

const ICONS = [['run', 'run'], ['course', 'run'], ['jog', 'run'], ['footing', 'run'], ['trail', 'run'],
  ['cycl', 'bike'], ['bike', 'bike'], ['vélo', 'bike'], ['velo', 'bike'], ['swim', 'swim'], ['natation', 'swim'],
  ['gym', 'gym'], ['muscu', 'gym'], ['weight', 'gym'], ['yoga', 'yoga'], ['walk', 'walk'], ['marche', 'walk'],
  ['hike', 'walk'], ['rando', 'walk']];
export const sportIcon = (sport) => ICONS.find(([k]) => sport.toLowerCase().includes(k))?.[1] ?? 'cardio';

// ---------- Santé (Apple Health) ----------
/** Turns the nightly rows sent by the Shortcut into per-month daily averages. */
export function healthMonths(rows) {
  const fields = ['steps', 'distance_km', 'active_kcal', 'resting_hr', 'sleep_h', 'flights'];
  const by = {};
  for (const r of rows) {
    const m = by[r.day.slice(0, 7)] ??= Object.fromEntries(fields.map((f) => [f, []]));
    for (const f of fields) if (r[f] != null && !(f === 'sleep_h' && r[f] === 0)) m[f].push(Number(r[f]));
  }
  const out = {};
  for (const [k, m] of Object.entries(by)) {
    out[k] = Object.fromEntries(fields.map((f) => [f, m[f].length ? m[f].reduce((a, b) => a + b, 0) / m[f].length : null]));
  }
  return out;
}
