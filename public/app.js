/* ============================================================================
   Performance — the app (screens, taps, saving)
   ----------------------------------------------------------------------------
   Opens instantly from what's saved on this device (localStorage), then syncs
   with Supabase in the background when signed in (cloud.js). Data rules —
   2am reset, monthly summaries, 3-month cleanup — live in logic.js.
   ============================================================================ */
import * as L from './logic.js';
import { quoteFor } from './quotes.js';
import * as Cloud from './cloud.js';

// ---------- storage ----------
function load(key, fallback) {
  try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch { return fallback; }
}
function keep(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* private mode: still works for this session */ }
}

let data = L.housekeep(load('perf-data', L.emptyData()));
let health = load('perf-health', []);            // nightly rows sent by the Santé Shortcut
let events = load('perf-events', { day: null, list: [], denied: false });
let now = new Date();

const ui = {
  tab: load('perf-tab', 'today'),
  hist: 'week', week: 0, month: 0, sel: null, year: 0,
  logging: false, form: { time: '', pace: '', sport: '', kcal: '' },
};

const $ = (s, el = document) => el.querySelector(s);
const view = $('#view');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const today = () => L.appDay(now);

// ---------- changing data ----------
/** Applies a change, keeps the data consistent, saves it and sends it to the other devices. */
function mutate(change, { redraw = true } = {}) {
  const before = L.canonical(data);
  const d = structuredClone(data);
  change(d);
  const after = L.housekeep(d, now);
  if (L.canonical(after) === before) return;
  data = after;
  keep('perf-data', data);
  Cloud.push(data);
  if (redraw) render();
}

/** Data arrived from the other device (or the cloud). */
function receive(remote) {
  if (!remote) { Cloud.push(data); return; }
  const merged = L.housekeep(L.merge(data, remote), now);
  const changed = L.canonical(merged) !== L.canonical(data);
  if (changed) { data = merged; keep('perf-data', data); render(); }
  if (L.canonical(merged) !== L.canonical(L.housekeep(remote, now))) Cloud.push(data);
}

// ---------- icons ----------
const I = {
  left: '<svg viewBox="0 0 24 24" class="ico" aria-hidden="true"><path d="M15 6l-6 6 6 6"/></svg>',
  right: '<svg viewBox="0 0 24 24" class="ico" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>',
  plus: '<svg viewBox="0 0 24 24" class="ico" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
  x: '<svg viewBox="0 0 24 24" class="ico" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  check: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12l5 5L20 7"/></svg>',
  heart: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s-7.5-4.6-9.5-9.3C1 8.2 3.2 4.5 6.8 4.5c2.1 0 3.6 1.1 5.2 3 1.6-1.9 3.1-3 5.2-3 3.6 0 5.8 3.7 4.3 7.2C19.5 16.4 12 21 12 21z"/></svg>',
  sport: {
    run: '<circle cx="14" cy="4" r="2"/><path d="M8 21l3-6 3 2v5M6 12l3-3 4 1 3 3 3 1"/>',
    bike: '<circle cx="5.5" cy="17" r="3.5"/><circle cx="18.5" cy="17" r="3.5"/><path d="M5.5 17l4-8h5l4 8M9.5 9L8 6H6M14.5 9l-3 8"/>',
    swim: '<circle cx="16" cy="7" r="2"/><path d="M5 13l5-4 3 3M2 18c2 0 2-1.5 4-1.5s2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5"/>',
    gym: '<path d="M6 8v8M18 8v8M3 10v4M21 10v4M6 12h12"/>',
    yoga: '<circle cx="12" cy="4" r="2"/><path d="M12 6v7M5 10l7 3 7-3M8 21l4-8 4 8"/>',
    walk: '<circle cx="13" cy="4" r="2"/><path d="M10 21l2-7 3 3v4M8 11l3-3h3l2 4"/>',
    cardio: '<path d="M3 12h4l2-5 4 10 2-5h6"/>',
  },
};
const flame = `<svg viewBox="0 0 64 76" aria-hidden="true">
  <defs>
    <linearGradient id="flO" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FF3D00"/><stop offset=".55" stop-color="#FF7A00"/><stop offset="1" stop-color="#FFC94A"/></linearGradient>
    <linearGradient id="flI" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFB300"/><stop offset="1" stop-color="#FFF1BF"/></linearGradient>
  </defs>
  <path d="M32 2C36 16 52 24 54 44C56 62 45 74 32 74C19 74 8 63 10 46C11 36 17 30 21 24C22 32 25 36 29 38C27 26 28 14 32 2Z" fill="url(#flO)"/>
  <path d="M32 34C36 42 44 48 43 58C42 66 37 70 32 70C26 70 21 65 22 58C23 51 28 47 30 42C31 46 33 48 35 49C34 44 33 39 32 34Z" fill="url(#flI)"/>
</svg>`;

// ---------- date words ----------
const DOW = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
const MON = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const MONTH = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
const dShort = (d) => `${d.getDate()} ${MON[d.getMonth()]}`;
const hhmm = (d) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;

// ---------- shared pieces ----------
const label = (t, extra = '') => `<span class="label"${extra}>${esc(t)}</span>`;
const bar = (v, color) => `<div class="bar"><i style="width:${Math.round(Math.max(0, Math.min(1, v)) * 100)}%${color ? `;background:${color}` : ''}"></i></div>`;
const stat = (value, unit) => `<div class="stat"><div class="num">${esc(value)}</div><small>${esc(unit)}</small></div>`;
const arrows = (act, title, nextDisabled = false) => `
  <div class="nav">
    <button class="arrow" data-act="${act}" data-n="-1" aria-label="Previous">${I.left}</button>
    <div class="num">${esc(title)}</div>
    <button class="arrow" data-act="${act}" data-n="1" aria-label="Next"${nextDisabled ? ' disabled' : ''}>${I.right}</button>
  </div>`;

function workoutRow(w, deletable) {
  const sp = L.parseSpeed(w.pace);
  const p = sp && L.paceText(sp.kmh, sp.style);
  return `<div class="wk">
    <div class="ic"><svg viewBox="0 0 24 24" aria-hidden="true">${I.sport[L.sportIcon(w.sport)]}</svg></div>
    <div class="who"><b>${esc(w.sport)}</b><span class="small">${hhmm(new Date(w.date))}</span></div>
    ${stat(L.fmtDuration(w.minutes), 'TIME')}
    ${p ? stat(p.value, p.unit) : ''}
    ${w.calories ? stat(w.calories, 'KCAL') : ''}
    ${deletable ? `<button class="del" data-act="del-workout" data-id="${w.id}" aria-label="Delete ${esc(w.sport)}">${I.x}</button>` : ''}
  </div>`;
}

// ============================================================================
// TODAY
// ============================================================================
function renderToday() {
  const t = today();
  const fuel = quoteFor(t);
  const rec = data.days[L.dayKey(t)];
  const items = L.activeSchedule(data);
  const done = items.filter((i) => L.isDone(rec, i.id)).length;
  const streak = L.streak(data, now);
  const workouts = L.activeWorkouts(data).filter((w) => L.sameDay(L.appDay(new Date(w.date)), t)).sort((a, b) => b.date - a.date);
  const s = Cloud.state();

  return `
  <header class="date-head">
    <div><div class="day">${DOW[t.getDay()]}</div><div class="date">${dShort(t)}</div></div>
    <div class="sync${s.status === 'synced' ? ' on' : ''}"><i></i>${{ synced: 'Synced', syncing: 'Syncing', offline: 'Offline', local: 'This device' }[s.status] ?? ''}</div>
  </header>

  <section class="card fuel">
    ${label(fuel.kind)}
    <p>${esc(fuel.text)}</p>
    <span class="small">${esc(fuel.source)}</span>
  </section>

  <div class="duo">
    ${renderCalendar()}
    <section class="card streak" style="--glow:${streak ? .28 : .08}" aria-label="${streak} day streak">
      ${flame}<div class="num">${streak}</div><div class="lbl">DAY STREAK</div>
    </section>
  </div>

  <section class="card sched">
    <div class="row-head">
      ${label('SCHEDULE')}
      <div style="display:flex;align-items:center;gap:10px">
        <span class="count">${done}<span class="dim">/${items.length}</span></span>
        <button class="add" data-act="add-item" aria-label="Add activity">${I.plus}</button>
      </div>
    </div>
    ${bar(items.length ? done / items.length : 0)}
    ${items.map((i) => {
      const on = L.isDone(rec, i.id);
      return `<div class="task${on ? ' done' : ''}">
        <button class="body" data-act="edit-item" data-id="${i.id}"><span class="title">${esc(i.title)}</span><span class="small">by ${L.fmtTime(i.due)}</span></button>
        <button class="check" data-act="tick" data-id="${i.id}" aria-label="${on ? 'Untick' : 'Tick'} ${esc(i.title)}" aria-pressed="${on}"><i>${I.check}</i></button>
      </div>`;
    }).join('')}
  </section>

  <div class="notes">
    ${[['todo', 'TO DO'], ['projects', 'PROJECTS'], ['goals', 'LONG-TERM GOALS'], ['other', 'OTHER']].map(([k, l]) => `
      <label class="note"><span>${l}</span><textarea data-note="${k}" spellcheck="true">${esc(data.notes[k]?.text ?? '')}</textarea></label>`).join('')}
  </div>

  <section class="card train">
    <div class="row-head">${label('TRAINING')}${workouts.length ? `<span class="small">${workouts.length} today</span>` : ''}</div>
    ${workouts.map((w) => workoutRow(w, true)).join('')}
    ${ui.logging ? `
    <form class="form" data-form="workout" autocomplete="off">
      <label>TIME<input name="time" inputmode="numeric" placeholder="45:00" value="${esc(ui.form.time)}"></label>
      <label>PACE<input name="pace" placeholder="5:10/km" value="${esc(ui.form.pace)}"></label>
      <label>SPORT<input name="sport" class="text" placeholder="Running" value="${esc(ui.form.sport)}"></label>
      <label>KCAL<input name="kcal" class="opt" inputmode="numeric" placeholder="—" value="${esc(ui.form.kcal)}"></label>
      <button class="btn primary" type="submit"${canSaveWorkout() ? '' : ' disabled'}>SAVE</button>
    </form>` : ''}
    <button class="btn ghost" data-act="toggle-log">${ui.logging ? `${I.x} CANCEL` : `${I.plus} LOG WORKOUT`}</button>
  </section>`;
}

function renderCalendar() {
  const list = events.day === L.dayKey(new Date()) ? events.list : [];
  const max = 4;
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  // calshow: opens Calendar on iPhone at that moment; ical:// opens Calendar on the Mac.
  const href = (e) => (ios ? `calshow:${Math.floor((e ? e.start : Date.now()) / 1000) - 978307200}` : 'ical://');
  const row = (color, time, title, e) => `<a class="ev" href="${href(e)}"><b style="background:${color}"></b>${time ? `<span class="t">${time}</span>` : ''}<span class="n">${esc(title)}</span>${I.right}</a>`;
  let body;
  if (!Cloud.state().enabled) body = row('var(--faint)', '', 'Not connected', null);
  else if (events.denied) body = row('var(--faint)', '', 'No calendar access', null);
  else if (!list.length) body = row('var(--faint)', '', 'Nothing today', null);
  else {
    body = list.slice(0, max).map((e) => row(/^#[0-9a-f]{3,8}$/i.test(e.color || '') ? e.color : 'var(--accent)', e.allDay ? 'ALL' : hhmm(new Date(e.start)), e.title, e)).join('');
    if (list.length > max) body += row('var(--faint)', '', `+${list.length - max} more`, null);
  }
  return `<section class="card cal">
    <div class="row-head">${label('CALENDAR')}${list.length ? `<span class="small">${list.length} event${list.length > 1 ? 's' : ''}</span>` : ''}</div>
    ${body}
  </section>`;
}

const canSaveWorkout = () => (L.parseMinutes(ui.form.time) ?? 0) > 0 && ui.form.sport.trim() !== '';

// ============================================================================
// HISTORY
// ============================================================================
function renderHistory() {
  return `
  <div class="top">
    <div class="page-title">HISTORY</div>
    <div class="seg" role="group">
      <button data-act="hist" data-mode="week" aria-pressed="${ui.hist === 'week'}">WEEK</button>
      <button data-act="hist" data-mode="month" aria-pressed="${ui.hist === 'month'}">MONTH</button>
    </div>
  </div>
  ${ui.hist === 'week' ? renderWeek() : renderMonth()}`;
}

const record = (day) => data.days[L.dayKey(day)];
const dayCircle = (day, size = '') => {
  const st = L.status(data, day, now);
  const sel = ui.sel && L.sameDay(ui.sel, day) ? ' sel' : '';
  return `<span class="dc ${st}${sel}"${size}>${day.getDate()}</span>`;
};

function renderWeek() {
  const start = L.addDays(L.startOfWeek(today()), ui.week * 7);
  const days = Array.from({ length: 7 }, (_, i) => L.addDays(start, i));
  const end = days[6];
  const title = (start.getMonth() === end.getMonth() ? `${start.getDate()}` : dShort(start)) + ' – ' + dShort(end);
  const workouts = L.activeWorkouts(data).filter((w) => { const d = L.appDay(new Date(w.date)); return d >= start && d <= end; });
  const kcal = workouts.reduce((s, w) => s + (Number(w.calories) || 0), 0);
  return `
  <section class="card" style="padding:12px 8px 16px">
    ${arrows('week', title)}
    <div class="strip">
      ${days.map((d) => `<button data-act="pick-day" data-day="${L.dayKey(d)}" aria-label="${DOW[d.getDay()]} ${d.getDate()}">
        <span class="dow">${DOW[d.getDay()].slice(0, 3)}</span>${dayCircle(d)}</button>`).join('')}
    </div>
  </section>
  ${ui.sel ? renderDay(ui.sel) : `
    ${renderTotals('THIS WEEK', L.counts(days.map(record).filter(Boolean)))}
    ${workouts.length ? `<section class="card">${label('TRAINING')}
      <div class="tiles" style="margin-top:10px">
        <div class="tile"><div class="num">${L.fmtHours(workouts.reduce((s, w) => s + w.minutes, 0))}</div><small>HOURS</small></div>
        <div class="tile"><div class="num">${workouts.length}</div><small>SESSIONS</small></div>
        <div class="tile"><div class="num">${kcal ? L.fmtThousands(kcal) : '—'}</div><small>KCAL</small></div>
      </div></section>` : ''}`}`;
}

function renderTotals(title, counts) {
  const done = counts.reduce((s, c) => s + c.done, 0), total = counts.reduce((s, c) => s + c.scheduled, 0);
  return `<section class="card">
    <div class="row-head" style="padding-bottom:8px">${label(title)}${total ? `<span class="num" style="font-size:18px">${done}<span class="dim">/${total}</span></span>` : ''}</div>
    ${counts.length ? counts.map((c) => `<div class="tot">
      <div class="row-head"><span style="font-weight:600">${esc(c.title)}</span><span class="num">${c.done}<small>/${c.scheduled}</small></span></div>
      ${bar(c.done / c.scheduled)}</div>`).join('') : '<div class="empty">No data</div>'}
  </section>`;
}

function renderDay(day) {
  const r = record(day);
  const isToday = L.sameDay(day, today());
  const workouts = L.activeWorkouts(data).filter((w) => L.sameDay(L.appDay(new Date(w.date)), day));
  const n = r ? L.itemCount(r) : 0, d = r ? L.doneCount(r) : 0;
  const color = n && d === n ? 'var(--green)' : (!isToday ? 'var(--red-text)' : 'var(--text)');
  return `<section class="card">
    <div class="row-head" style="padding-bottom:8px">${label(`${DOW[day.getDay()].slice(0, 3)} ${dShort(day)}`)}${n ? `<span class="num" style="font-size:18px;color:${color}">${d}/${n}</span>` : ''}</div>
    ${n ? Object.entries(r.items).sort((a, b) => a[1].localeCompare(b[1])).map(([id, title]) =>
      `<div class="ditem${L.isDone(r, id) ? ' on' : ''}"><i>${I.check}</i><span>${esc(title)}</span></div>`).join('') : '<div class="empty">No data</div>'}
    ${workouts.length ? `<div style="display:flex;flex-direction:column;gap:8px;margin-top:12px">${workouts.map((w) => workoutRow(w, false)).join('')}</div>` : ''}
  </section>`;
}

function renderMonth() {
  const first = L.addMonths(L.startOfMonth(today()), ui.month);
  const days = L.daysInMonth(first);
  const lead = (first.getDay() + 6) % 7;
  const statuses = days.map((d) => L.status(data, d, now));
  const summary = data.months[L.monthKey(first)];
  const live = statuses.some((s) => s === 'perfect' || s === 'missed');
  const green = live ? statuses.filter((s) => s === 'perfect').length : (summary?.perfectDays ?? 0);
  const red = live ? statuses.filter((s) => s === 'missed').length : (summary?.missedDays ?? 0);

  // Activity totals: live while daily detail exists, from the frozen summary afterwards.
  const records = days.map(record).filter(Boolean);
  let counts = records.length ? L.counts(records)
    : Object.entries(summary?.activity ?? {}).map(([title, done]) => ({ title, done }));
  counts = counts.sort((a, b) => b.done - a.done || a.title.localeCompare(b.title));
  const top = Math.max(1, ...counts.map((c) => c.done));

  return `
  <section class="card" style="padding:12px 10px 16px">
    ${arrows('month', `${MONTH[first.getMonth()]} ${first.getFullYear()}`)}
    <div class="month">
      ${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((w) => `<span class="dow">${w}</span>`).join('')}
      ${'<span></span>'.repeat(lead)}
      ${days.map((d) => `<button data-act="pick-day" data-day="${L.dayKey(d)}" aria-label="${d.getDate()} ${MONTH[d.getMonth()]}">${dayCircle(d)}</button>`).join('')}
    </div>
    ${green + red ? `<div class="legend"><span><i style="border-color:var(--green)"></i>${green}</span><span><i style="border-color:var(--red)"></i>${red}</span></div>` : ''}
  </section>
  ${ui.sel ? renderDay(ui.sel) : ''}
  <section class="card">
    <div class="row-head" style="padding-bottom:8px">${label(MONTH[first.getMonth()])}<span class="small">times done</span></div>
    ${counts.length ? counts.map((c) => `<div class="mrow"><span class="name">${esc(c.title)}</span>${bar(c.done / top)}<span class="num">${c.done}</span></div>`).join('')
      : '<div class="empty">No data</div>'}
  </section>`;
}

// ============================================================================
// STATS
// ============================================================================
function renderStats() {
  const year = today().getFullYear() + ui.year;
  const months = Array.from({ length: 12 }, (_, i) => new Date(year, i, 1));
  const currentKey = L.monthKey(today());
  const lastKey = L.monthKey(L.addMonths(L.startOfMonth(today()), -1));
  const prevKey = L.monthKey(L.addMonths(L.startOfMonth(today()), -2));
  const last = data.months[lastKey];

  // Schedule completion per month (months down the side, % across).
  const pts = months.map((m) => ({ m, key: L.monthKey(m), v: L.completion(data, L.monthKey(m), now) }));
  const finished = pts.filter((p) => p.v != null && p.key !== currentKey);
  const avg = finished.length ? Math.round(finished.reduce((s, p) => s + p.v, 0) / finished.length * 100) : null;

  let delta = null;
  if (last) {
    const prev = data.months[prevKey];
    if (!prev) delta = [L.fmtHours(last.sports.reduce((s, x) => s + x.minutes, 0)), 'var(--text)'];
    else {
      const diff = last.sports.reduce((s, x) => s + x.minutes, 0) - prev.sports.reduce((s, x) => s + x.minutes, 0);
      delta = [(diff >= 0 ? '+' : '−') + L.fmtHours(Math.abs(diff)), diff >= 0 ? 'var(--green)' : 'var(--red-text)'];
    }
  }

  return `
  <div class="top">
    <div class="page-title">STATS</div>
    <div style="display:flex;align-items:center">
      <button class="arrow" data-act="year" data-n="-1" aria-label="Previous year">${I.left}</button>
      <span class="num" style="font-size:20px">${year}</span>
      <button class="arrow" data-act="year" data-n="1" aria-label="Next year"${ui.year >= 0 ? ' disabled' : ''}>${I.right}</button>
    </div>
  </div>

  <div class="src"><i></i><b>THIS APP</b><hr></div>

  <section class="card">
    <div class="row-head">${label('SCHEDULE COMPLETED')}${avg != null ? `<span><span class="num" style="font-size:22px">${avg}%</span><span class="small"> avg</span></span>` : ''}</div>
    <div class="hbars">
      ${pts.map((p) => `<div class="hbar"><span class="m">${MON[p.m.getMonth()]}</span>
        <span class="track"><i class="${p.key === currentKey ? 'live' : ''}" style="width:${p.v != null ? Math.round(p.v * 100) : 0}%"></i></span>
        <span class="v"${p.key === currentKey ? ' style="color:var(--muted)"' : ''}>${p.v != null ? Math.round(p.v * 100) + '%' : '<span class="dim">—</span>'}</span></div>`).join('')}
    </div>
    <div class="axis"><span>0%</span><span>50%</span><span>100%</span></div>
  </section>

  ${last && ui.year === 0 && last.sports.length ? renderSportMonth(last) : ''}

  ${vbars('SPORT HOURS / MONTH', months, 'var(--accent)', (k) => data.months[k] && data.months[k].sports.reduce((s, x) => s + x.minutes, 0) / 60, delta, (v) => L.fmtHours(v * 60))}
  ${vbars('CARDIO HOURS / MONTH', months, 'var(--orange)', (k) => data.months[k] && data.months[k].cardioMinutes / 60,
    last ? [L.fmtHours(last.cardioMinutes), 'var(--orange)'] : null, (v) => L.fmtHours(v * 60))}

  ${renderHealth(months)}`;
}

function renderSportMonth(s) {
  const total = s.sports.reduce((t, x) => t + x.minutes, 0);
  const sessions = s.sports.reduce((t, x) => t + x.sessions, 0);
  const top = Math.max(1, s.sports[0]?.minutes ?? 1);
  return `<section class="card">
    <div class="row-head">${label(`SPORT · ${MONTH[L.parseMonth(s.key).getMonth()]}`)}<span class="small">${sessions} session${sessions === 1 ? '' : 's'}</span></div>
    <div class="big"><span class="num">${L.fmtHours(total)}</span><span class="small">hours</span></div>
    ${s.sports.map((x, i) => {
      const p = x.avgKmh ? L.paceText(x.avgKmh, x.style) : { value: '—', unit: '' };
      return `<div class="rank"><span class="num">${i + 1}</span>
        <div class="who"><b>${esc(x.name)}</b>${bar(x.minutes / top)}</div>
        ${stat(L.fmtHours(x.minutes), 'HOURS')}${stat(p.value, p.unit)}</div>`;
    }).join('')}
  </section>`;
}

/** Vertical bars, one per month; the latest month with data is drawn brighter. */
function vbars(title, months, color, value, trailing, fmt) {
  const vals = months.map((m) => value(L.monthKey(m)) || 0);
  const max = Math.max(...vals);
  const latest = vals.reduce((li, v, i) => (v > 0 ? i : li), -1);
  return `<section class="card">
    <div class="row-head">${label(title)}${trailing ? `<span class="num" style="font-size:18px;color:${trailing[1]}">${trailing[0]}</span>` : ''}</div>
    <div class="vbars">
      ${vals.map((v, i) => `<div>${v && i === latest ? `<small>${fmt(v)}</small>` : ''}<i style="height:${max ? Math.round(v / max * 82) : 0}%;background:${color};opacity:${i === latest ? 1 : .6}"></i></div>`).join('')}
    </div>
    <div class="vlabels">${months.map((m) => `<span>${MON[m.getMonth()][0]}</span>`).join('')}</div>
  </section>`;
}

function spark(values) {
  if (values.length < 2) return '';
  const mx = Math.max(...values), mn = Math.min(...values);
  const pts = values.map((v, i) => `${(i / (values.length - 1) * 100).toFixed(1)},${(26 - (v - mn) / ((mx - mn) || 1) * 24).toFixed(1)}`).join(' ');
  return `<svg viewBox="0 0 100 28" preserveAspectRatio="none" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="#FF6F8A" stroke-width="2" vector-effect="non-scaling-stroke" stroke-linejoin="round"/></svg>`;
}

function renderHealth(months) {
  const hm = L.healthMonths(health);
  const lastKey = L.monthKey(L.addMonths(L.startOfMonth(today()), -1));
  const shownKey = hm[lastKey] ? lastKey : L.monthKey(today());
  const m = hm[shownKey];
  const history = Object.keys(hm).sort().filter((k) => k <= shownKey).slice(-8).map((k) => hm[k]);
  const trend = (f) => history.map((h) => h[f]).filter((v) => v != null);
  const tile = (l, v, u, f) => `<div class="htile"><span class="l">${l}</span><div><span class="num">${v}</span><span class="u">${u}</span></div>${spark(trend(f))}</div>`;
  const n = (v, f) => (v == null ? '—' : f(v));

  const steps = months.map((mo) => hm[L.monthKey(mo)]?.steps || 0);
  const maxSteps = Math.max(...steps);
  const latest = steps.reduce((li, v, i) => (v > 0 ? i : li), -1);

  return `<section class="health" aria-label="Data from Santé">
    <div class="head"><span class="heart">${I.heart}</span>
      <div><b>SANTÉ</b>${m ? `<small>Daily activity · ${MONTH[L.parseMonth(shownKey).getMonth()].charAt(0) + MONTH[L.parseMonth(shownKey).getMonth()].slice(1).toLowerCase()}</small>` : ''}</div></div>
    ${m ? `
    <div class="htiles">
      ${tile('STEPS', n(m.steps, L.fmtThousands), '/day', 'steps')}
      ${tile('DISTANCE', n(m.distance_km, (v) => v.toFixed(1)), 'km/day', 'distance_km')}
      ${tile('ACTIVE ENERGY', n(m.active_kcal, L.fmtThousands), 'kcal/day', 'active_kcal')}
      ${tile('RESTING HR', n(m.resting_hr, Math.round), 'bpm', 'resting_hr')}
      ${tile('SLEEP', n(m.sleep_h, (v) => L.fmtHours(v * 60)), 'h/night', 'sleep_h')}
      ${tile('FLIGHTS', n(m.flights, Math.round), '/day', 'flights')}
    </div>
    <div class="card">
      <div class="row-head">${label('STEPS / DAY · MONTHLY AVG')}${m.steps != null ? `<span class="num" style="font-size:16px">${L.fmtThousands(m.steps)}</span>` : ''}</div>
      <div class="vbars">${steps.map((v, i) => `<div><i style="height:${maxSteps ? Math.round(v / maxSteps * 90) : 0}%;background:var(--health-soft);opacity:${i === latest ? 1 : .6}"></i></div>`).join('')}</div>
      <div class="vlabels">${months.map((mo) => `<span>${MON[mo.getMonth()][0]}</span>`).join('')}</div>
    </div>` : '<div class="empty">No data from Santé yet</div>'}
  </section>`;
}

// ============================================================================
// SIGN IN (only when Supabase is configured and nobody is signed in)
// ============================================================================
let signMode = 'in';
function renderSignIn(error = '') {
  return `<form class="signin" data-form="signin">
    <div class="page-title">PERFORMANCE</div>
    <div class="seg" role="group" style="align-self:flex-start">
      <button type="button" data-act="sign-mode" data-mode="in" aria-pressed="${signMode === 'in'}">SIGN IN</button>
      <button type="button" data-act="sign-mode" data-mode="up" aria-pressed="${signMode === 'up'}">CREATE ACCOUNT</button>
    </div>
    <input class="field" name="email" type="email" autocomplete="email" placeholder="Email" aria-label="Email" value="${esc(load('perf-email', ''))}" required>
    <input class="field" name="password" type="password" autocomplete="${signMode === 'in' ? 'current-password' : 'new-password'}" placeholder="Password" aria-label="Password" minlength="8" required>
    <div class="err" role="alert">${esc(error)}</div>
    <button class="btn primary" type="submit">${signMode === 'in' ? 'SIGN IN' : 'CREATE ACCOUNT'}</button>
  </form>`;
}

// ============================================================================
// render
// ============================================================================
let pending = false;
function render() {
  // Never redraw under the cursor while typing in a note or the workout form.
  const a = document.activeElement;
  if (a && view.contains(a) && (a.tagName === 'TEXTAREA' || a.tagName === 'INPUT')) { pending = true; return; }
  pending = false;
  const s = Cloud.state();
  const needSignIn = s.enabled && !s.session && !s.hadSession;
  document.querySelector('.tabbar').hidden = needSignIn;
  if (needSignIn) { view.innerHTML = renderSignIn(); return; }
  for (const b of document.querySelectorAll('.tabbar button')) b.setAttribute('aria-current', b.dataset.tab === ui.tab ? 'page' : 'false');
  view.innerHTML = ui.tab === 'history' ? renderHistory() : ui.tab === 'stats' ? renderStats() : renderToday();
}
view.addEventListener('focusout', () => setTimeout(() => { if (pending) render(); }, 0));

// ============================================================================
// interactions
// ============================================================================
document.querySelector('.tabbar').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-tab]');
  if (!b) return;
  ui.tab = b.dataset.tab; ui.sel = null; keep('perf-tab', ui.tab);
  render(); window.scrollTo(0, 0);
});

view.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act;
  if (act === 'tick') {
    const key = L.dayKey(today());
    mutate((d) => {
      const rec = d.days[key] ?? { key, items: {}, ticks: {} };
      rec.ticks[el.dataset.id] = { done: !L.isDone(rec, el.dataset.id), modified: Date.now() };
      d.days[key] = rec;
    });
  } else if (act === 'add-item') openItem({ id: L.uid(), title: '', due: 18 * 60 }, true);
  else if (act === 'edit-item') openItem(data.schedule.find((i) => i.id === el.dataset.id), false);
  else if (act === 'toggle-log') { ui.logging = !ui.logging; render(); if (ui.logging) $('[name=time]', view)?.focus(); }
  else if (act === 'del-workout') {
    if (!confirm('Delete this workout?')) return;
    mutate((d) => { const w = d.workouts.find((x) => x.id === el.dataset.id); if (w) { w.deleted = true; w.modified = Date.now(); } });
  } else if (act === 'hist') { ui.hist = el.dataset.mode; ui.sel = null; render(); }
  else if (act === 'week') { ui.week += Number(el.dataset.n); ui.sel = null; render(); }
  else if (act === 'month') { ui.month += Number(el.dataset.n); ui.sel = null; render(); }
  else if (act === 'year') { ui.year = Math.min(0, ui.year + Number(el.dataset.n)); render(); }
  else if (act === 'pick-day') {
    const d = L.parseDay(el.dataset.day);
    ui.sel = ui.sel && L.sameDay(ui.sel, d) ? null : d; render();
  } else if (act === 'sign-mode') { signMode = el.dataset.mode; view.innerHTML = renderSignIn(); }
});

// Notes save as you type (no redraw, so the cursor never jumps).
let noteTimer;
view.addEventListener('input', (e) => {
  const t = e.target;
  if (t.dataset.note) {
    const k = t.dataset.note, text = t.value;
    clearTimeout(noteTimer);
    noteTimer = setTimeout(() => mutate((d) => { d.notes[k] = { text, modified: Date.now() }; }, { redraw: false }), 300);
  } else if (t.form?.dataset.form === 'workout') {
    ui.form[t.name] = t.value;
    t.form.querySelector('[type=submit]').disabled = !canSaveWorkout();
  }
});

view.addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = e.target;
  if (f.dataset.form === 'workout') {
    if (!canSaveWorkout()) return;
    const kcal = parseInt(ui.form.kcal, 10);
    const w = { id: L.uid(), date: Date.now(), minutes: L.parseMinutes(ui.form.time), pace: ui.form.pace.trim(),
      sport: L.sportName(ui.form.sport), calories: Number.isFinite(kcal) ? kcal : null, modified: Date.now(), deleted: false };
    ui.form = { time: '', pace: '', sport: '', kcal: '' }; ui.logging = false;
    document.activeElement?.blur();
    mutate((d) => { d.workouts.push(w); });
  } else if (f.dataset.form === 'signin') {
    const email = f.email.value.trim(), password = f.password.value;
    keep('perf-email', email);
    const btn = f.querySelector('[type=submit]'); btn.disabled = true;
    const err = signMode === 'in' ? await Cloud.signIn(email, password) : await Cloud.signUp(email, password);
    if (err) { view.innerHTML = renderSignIn(err); }
  }
});

// Swipe right → previous week/month/year, swipe left → next.
let touch = null;
view.addEventListener('touchstart', (e) => { touch = { x: e.touches[0].clientX, y: e.touches[0].clientY }; }, { passive: true });
view.addEventListener('touchend', (e) => {
  if (!touch || ui.tab === 'today') return;
  const dx = e.changedTouches[0].clientX - touch.x, dy = e.changedTouches[0].clientY - touch.y;
  touch = null;
  if (Math.abs(dx) < 60 || Math.abs(dx) < Math.abs(dy) * 1.5) return;
  const n = dx > 0 ? -1 : 1;
  if (ui.tab === 'stats') ui.year = Math.min(0, ui.year + n);
  else if (ui.hist === 'week') ui.week += n;
  else ui.month += n;
  ui.sel = null; render();
});

// ---------- add / edit activity sheet ----------
const sheet = $('#sheet');
function openItem(item, isNew) {
  if (!item) return;
  sheet.innerHTML = `<form class="panel" data-form="item" autocomplete="off">
    ${label(isNew ? 'NEW ACTIVITY' : 'ACTIVITY')}
    <input class="field" name="title" placeholder="Activity" aria-label="Activity" value="${esc(item.title)}" required>
    <div class="row-head">${label('COMPLETE BY')}<input class="field" type="time" name="due" aria-label="Complete by" value="${L.fmtTime(item.due)}" required></div>
    <div class="pair">
      ${isNew ? '<button type="button" class="btn quiet" data-sheet="close">CANCEL</button>'
        : '<button type="button" class="btn quiet" data-sheet="delete" style="color:var(--red-text)">DELETE</button>'}
      <button type="submit" class="btn primary">SAVE</button>
    </div>
  </form>`;
  sheet.hidden = false;
  const f = sheet.firstElementChild;
  const field = (n) => f.elements.namedItem(n);
  if (isNew) setTimeout(() => field('title').focus(), 50);
  f.addEventListener('submit', (e) => {
    e.preventDefault();
    const title = field('title').value.trim();
    if (!title) return;
    const [h, m] = (field('due').value || '18:00').split(':').map(Number);
    closeSheet();
    mutate((d) => {
      const i = d.schedule.findIndex((x) => x.id === item.id);
      const next = { ...item, title, due: h * 60 + m, modified: Date.now(), deleted: false };
      if (i >= 0) d.schedule[i] = next; else d.schedule.push(next);
    });
  });
  f.addEventListener('click', (e) => {
    const a = e.target.closest('[data-sheet]')?.dataset.sheet;
    if (a === 'close') closeSheet();
    if (a === 'delete') {
      closeSheet();
      mutate((d) => { const x = d.schedule.find((i) => i.id === item.id); if (x) { x.deleted = true; x.modified = Date.now(); } });
    }
  });
}
function closeSheet() { sheet.hidden = true; sheet.innerHTML = ''; }
sheet.addEventListener('click', (e) => { if (e.target === sheet) closeSheet(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !sheet.hidden) closeSheet(); });

// ============================================================================
// clock: the 2am reset while the app stays open
// ============================================================================
setInterval(() => {
  const before = L.dayKey(today());
  now = new Date();
  if (L.dayKey(today()) !== before) {
    data = L.housekeep(data, now); keep('perf-data', data); Cloud.push(data);
    render();
  }
}, 30_000);

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'visible') return;
  now = new Date();
  data = L.housekeep(data, now);
  render();
  Cloud.refresh();
});

// ============================================================================
// start: draw from this device first (instant), then sync
// ============================================================================
render();
Cloud.start({
  onRemote: receive,
  onHealth: (rows) => { health = rows; keep('perf-health', rows); if (ui.tab === 'stats') render(); },
  onEvents: (ev) => { events = ev; keep('perf-events', ev); if (ui.tab === 'today') render(); },
  onChange: () => render(),
});

if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js');
