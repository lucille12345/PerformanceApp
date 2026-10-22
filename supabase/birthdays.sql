-- ============================================================================
-- Performance — birthdays from your Contacts (added after the first setup)
-- Paste into Supabase → SQL Editor → New query → Run. Safe to re-run.
-- The iPhone Shortcut sends the list (through /api/birthdays); the app only reads it.
-- ============================================================================
create table if not exists public.perf_birthdays (
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  month      smallint not null check (month between 1 and 12),
  day        smallint not null check (day between 1 and 31),
  year       smallint,
  updated_at timestamptz not null default now(),
  primary key (user_id, name, month, day)
);

alter table public.perf_birthdays enable row level security;

drop policy if exists "own birthdays: read" on public.perf_birthdays;
create policy "own birthdays: read" on public.perf_birthdays for select using (auth.uid() = user_id);
