/* ============================================================================
   Performance — sync with Supabase
   ----------------------------------------------------------------------------
   Turns on only when config.js has the Supabase url + publishable key;
   otherwise the app simply keeps everything on this device.

   • Your whole data set is one row in `perf_state`. Each device merges what it
     receives with what it has (newest change wins) and writes back only if the
     result differs — so phone and computer always end up identical.
   • Realtime pushes every change to the other device within a second.
   • `perf_health` holds the nightly Santé numbers sent by the iPhone Shortcut.
   • /api/calendar (a Cloudflare function) reads today's events from your
     calendar link.
   • Birthdays come from `perf_birthdays` (iPhone Shortcut) and from the
     list file the Worker serves at /api/birthdays; both are combined.
   ============================================================================ */

const cfg = window.PERF_CONFIG || {};
const enabled = Boolean(cfg.supabaseUrl && cfg.supabaseKey);

let client = null;
let session = null;
let status = enabled ? 'syncing' : 'local';
let handlers = {};
let channel = null;
let pushTimer = null;
let latest = null;

const hadSession = () => { try { return localStorage.getItem('perf-signed-in') === '1'; } catch { return false; } };
const setHad = (v) => { try { v ? localStorage.setItem('perf-signed-in', '1') : localStorage.removeItem('perf-signed-in'); } catch {} };

export const state = () => ({ enabled, session, status, hadSession: !!session || hadSession() });

function setStatus(s) {
  if (s === status) return;
  status = s;
  handlers.onChange?.();
}

export async function start(h) {
  handlers = h;
  if (!enabled) return;
  try {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2.45.4');
    client = createClient(cfg.supabaseUrl, cfg.supabaseKey, { auth: { persistSession: true, autoRefreshToken: true } });
  } catch {
    setStatus('offline');
    setTimeout(() => start(h), 15_000);
    return;
  }
  session = (await client.auth.getSession()).data.session;
  if (!session) setHad(false);
  handlers.onChange?.();
  client.auth.onAuthStateChange((event, s) => {
    const was = session?.user?.id;
    session = s;
    setHad(!!s);
    if (s && s.user.id !== was) connect();
    if (!s) { channel?.unsubscribe(); channel = null; }
    handlers.onChange?.();
  });
  if (session) connect();
  window.addEventListener('online', () => refresh());
  window.addEventListener('offline', () => setStatus('offline'));
}

function connect() {
  channel?.unsubscribe();
  channel = client.channel('perf-state')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'perf_state', filter: `user_id=eq.${session.user.id}` },
      (p) => { if (p.new?.data) { latest = p.new.data; handlers.onRemote?.(p.new.data); } })
    .subscribe();
  refresh();
}

/** Pull the latest data, Santé numbers and today's events (on open, when the app comes back,
    and from the reload buttons — `fresh` makes the calendar skip its 5-minute cache). */
export async function refresh({ fresh = false } = {}) {
  if (!client || !session) return;
  setStatus('syncing');
  const { data, error } = await client.from('perf_state').select('data').eq('user_id', session.user.id).maybeSingle();
  if (error) { setStatus(navigator.onLine ? 'syncing' : 'offline'); return; }
  latest = data?.data ?? null;
  handlers.onRemote?.(latest);
  setStatus('synced');
  await Promise.all([loadHealth(), loadEvents(fresh), loadBirthdays()]);
}

async function loadBirthdays() {
  const [table, file] = await Promise.all([
    client.from('perf_birthdays').select('name,month,day,year').eq('user_id', session.user.id)
      .then(({ data, error }) => (error ? null : data)).catch(() => null),
    fetch('/api/birthdays', { headers: { Authorization: `Bearer ${session.access_token}` } })
      .then((r) => (r.ok ? r.json() : null)).then((b) => b?.birthdays ?? null).catch(() => null),
  ]);
  if (!table && !file) return;                        // nothing reachable: keep the last list
  const all = new Map();
  for (const b of [...(file ?? []), ...(table ?? [])]) all.set(`${b.name.toLowerCase()}|${b.month}|${b.day}`, b);
  handlers.onBirthdays?.([...all.values()]);
}

/** Save to the cloud half a second after the last change. */
export function push(appData) {
  if (!client || !session) return;
  clearTimeout(pushTimer);
  pushTimer = setTimeout(async () => {
    setStatus('syncing');
    const { error } = await client.from('perf_state')
      .upsert({ user_id: session.user.id, data: appData, updated_at: new Date().toISOString() });
    setStatus(error ? (navigator.onLine ? 'syncing' : 'offline') : 'synced');
    if (error && navigator.onLine) setTimeout(() => push(appData), 5000);
  }, 500);
}

async function loadHealth() {
  const since = new Date(); since.setMonth(since.getMonth() - 13);
  const { data, error } = await client.from('perf_health').select('day,steps,distance_km,active_kcal,resting_hr,sleep_h,flights,updated_at')
    .eq('user_id', session.user.id).gte('day', since.toISOString().slice(0, 10)).order('day');
  if (!error && data) handlers.onHealth?.(data);
}

async function loadEvents(fresh = false) {
  const from = new Date(); from.setHours(0, 0, 0, 0);
  const to = new Date(from); to.setDate(to.getDate() + 1);
  const day = `${from.getFullYear()}-${String(from.getMonth() + 1).padStart(2, '0')}-${String(from.getDate()).padStart(2, '0')}`;
  try {
    const r = await fetch(`/api/calendar?from=${from.getTime()}&to=${to.getTime()}&day=${day}${fresh ? '&fresh=1' : ''}`,
      { headers: { Authorization: `Bearer ${session.access_token}` } });
    if (r.status === 404) return;                     // calendar function not deployed (local testing)
    const body = await r.json();
    handlers.onEvents?.({ day, list: body.events ?? [], denied: !r.ok });
  } catch { /* offline: keep the last events we had */ }
}

// ---------- sign in ----------
const friendly = (e) => {
  const m = e?.message || '';
  if (/invalid login/i.test(m)) return 'Wrong email or password.';
  if (/already registered/i.test(m)) return 'That email already has an account — sign in instead.';
  if (/password/i.test(m)) return 'Use at least 8 characters for the password.';
  if (/confirm/i.test(m)) return 'Confirm your email first (check your inbox), then sign in.';
  return m || 'Something went wrong. Try again.';
};

export async function signIn(email, password) {
  if (!client) return 'No connection — try again in a moment.';
  const { error } = await client.auth.signInWithPassword({ email, password });
  return error ? friendly(error) : null;
}

export async function signUp(email, password) {
  if (!client) return 'No connection — try again in a moment.';
  const { data, error } = await client.auth.signUp({ email, password });
  if (error) return friendly(error);
  return data.session ? null : 'Check your inbox to confirm your email, then sign in.';
}
