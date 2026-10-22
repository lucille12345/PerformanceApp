-- ============================================================================
-- Performance — Supabase tables
-- Paste all of this into Supabase → SQL Editor → New query → Run. Safe to re-run.
-- ============================================================================

-- Everything the app stores (schedule, ticks, notes, workouts, monthly stats):
-- one JSON document per account, merged by each device.
create table if not exists public.perf_state (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.perf_state enable row level security;

drop policy if exists "own state: read"   on public.perf_state;
drop policy if exists "own state: insert" on public.perf_state;
drop policy if exists "own state: update" on public.perf_state;
create policy "own state: read"   on public.perf_state for select using (auth.uid() = user_id);
create policy "own state: insert" on public.perf_state for insert with check (auth.uid() = user_id);
create policy "own state: update" on public.perf_state for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Live updates to the other device.
do $$ begin
  alter publication supabase_realtime add table public.perf_state;
exception when duplicate_object then null; end $$;

-- Santé numbers, one row per day, written each night by the iPhone Shortcut
-- (through /api/health). The app only reads them.
create table if not exists public.perf_health (
  user_id     uuid not null references auth.users (id) on delete cascade,
  day         date not null,
  steps       numeric,
  distance_km numeric,
  active_kcal numeric,
  resting_hr  numeric,
  sleep_h     numeric,
  flights     numeric,
  updated_at  timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.perf_health enable row level security;

drop policy if exists "own health: read" on public.perf_health;
create policy "own health: read" on public.perf_health for select using (auth.uid() = user_id);
