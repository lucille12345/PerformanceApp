# Performance — project memory

Personal productivity + sport web app for Lucille. **Live stack:** static PWA in `public/` (no build step,
ES modules) served by a **Cloudflare Worker** (`worker/index.js` + `wrangler.jsonc`, static assets = `public/`,
Worker name `performance-app` must match the dashboard), data in **Supabase**, `/api/calendar` + `/api/health` in `worker/`.
`native/` = abandoned SwiftUI version (free Apple ID apps expire every 7 days) — don't touch unless asked.

## Rules that matter
- **No instructional/"how to use" text in the UI** (Lucille's explicit design rule). Garmin-style dark look;
  design source: artifact https://claude.ai/artifact/U8yQDA8tab3dzKRhDjihEH.
- **Santé data stays visibly separate** from app data (pink `.health` section under "THIS APP").
- App day starts **03:00** (`RESET_HOUR`). Finished months are frozen into
  `data.months[...]`; daily detail older than `KEEP_MONTHS` (3) is deleted (`housekeep` in `logic.js`).
- **Every day has its own plan** (Lucille, 30 Oct 2026): each activity has `day` (dayKey). A new day starts
  empty; the Today page plans TODAY or TOMORROW, the sheet's DAY field (and the calendar box's +, and
  History → any day ≥ today) plans any later day. `data.days[k].items` is rebuilt from the activities planned
  for k, so a day's green/red never depends on another day. Old repeating items (no `day`) migrate to the day
  the new code first runs. Old records are repaired: an item deleted before a day ended is dropped from it.
- **Streak** = finished days in a row with everything ticked (today counts only after 03:00). Days with nothing
  planned break it. Longest ever = `data.bestStreak` (merge = max); `streakCarry` keeps a streak alive across
  the 3-month cleanup.
- **Hours log** (`data.log[dayKey].work|sport|phone = {min, modified}`), typed on Today / History day.
  Only the current week keeps daily values; finished weeks become `data.weeks[mondayKey]` totals.
- **Note boxes** = `data.boxes` ({id,title,order,deleted}); text stays in `data.notes[id]`. Defaults keep the
  old ids (todo, projects, goals, other).
- Sync = one JSON doc per user in `perf_state`; every entity has `modified`; `merge()` is newest-wins and
  order-independent; devices write back only when the merged result differs (`receive` in `app.js`).
- **Instant open:** `sw.js` serves the cached shell first and refreshes in the background. **Bump `CACHE`**
  in `sw.js` whenever `SHELL` changes.
- Secrets live only in Cloudflare Worker variables (`keep_vars: true` keeps them across deploys) (`SUPABASE_SECRET_KEY`, `HEALTH_KEY`, `CALENDAR_URLS`); the non-secret ones (Supabase URL + publishable key, `TIMEZONE`,
  `OWNER_USER_ID`) are `vars` in `wrangler.jsonc`. Saving a secret in the dashboard can create a version without them — then retry the latest build.

## Schedule vs to-do activities
Each activity has `kind`: `'schedule'` (default; shows "by HH:MM", sorted by `due`) or `'todo'` (shows its
duration `span` in minutes, no due time; listed after schedule items). Chosen in the add/edit sheet.

## Calendar box extras
- `holidays.js`: French fériés/fêtes, Catholic (Easter-based), Jewish (Intl hebrew calendar), US, world — computed on device.
- Birthdays: Shortcut → `POST /api/birthdays` (HEALTH_KEY) → `perf_birthdays` (replace-all), **plus** the list file
  `data/birthdays.txt` ("Name | date" lines) served to the owner by `GET /api/birthdays`. The app combines both.
- Reload buttons: calendar box (refetch, calendar with `fresh=1` = no 5-min cache) and Santé (on iPhone also runs
  the Shortcut named `healthShortcut` in `config.js` through `shortcuts://run-shortcut`).
- Santé in Stats: DAY (latest row) / 7 DAYS / MONTH (the original monthly view).

## Test locally
`python3 -m http.server 8790 -d public` (launch config "performance"). Functions don't run locally;
the calendar box shows a placeholder when Supabase isn't configured.
