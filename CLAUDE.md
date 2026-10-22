# Performance — project memory

Personal productivity + sport web app for Lucille. **Live stack:** static PWA in `public/` (no build step,
ES modules) served by a **Cloudflare Worker** (`worker/index.js` + `wrangler.jsonc`, static assets = `public/`,
Worker name `performance-app` must match the dashboard), data in **Supabase**, `/api/calendar` + `/api/health` in `worker/`.
`native/` = abandoned SwiftUI version (free Apple ID apps expire every 7 days) — don't touch unless asked.

## Rules that matter
- **No instructional/"how to use" text in the UI** (Lucille's explicit design rule). Garmin-style dark look;
  design source: artifact https://claude.ai/artifact/U8yQDA8tab3dzKRhDjihEH.
- **Santé data stays visibly separate** from app data (pink `.health` section under "THIS APP").
- App day starts **02:00** (`RESET_HOUR`). Days never opened = missed (red). Finished months are frozen into
  `data.months[...]`; daily detail older than `KEEP_MONTHS` (3) is deleted (`housekeep` in `logic.js`).
- Sync = one JSON doc per user in `perf_state`; every entity has `modified`; `merge()` is newest-wins and
  order-independent; devices write back only when the merged result differs (`receive` in `app.js`).
- **Instant open:** `sw.js` serves the cached shell first and refreshes in the background. **Bump `CACHE`**
  in `sw.js` whenever `SHELL` changes.
- Secrets live only in Cloudflare Worker variables (`keep_vars: true` keeps them across deploys) (`SUPABASE_SECRET_KEY`, `HEALTH_KEY`, `CALENDAR_URLS`,
  `OWNER_USER_ID`). `config.js` holds only the publishable key.

## Calendar box extras
- `holidays.js`: French fériés/fêtes, Catholic (Easter-based), Jewish (Intl hebrew calendar), US, world — computed on device.
- Birthdays: Shortcut → `POST /api/birthdays` (HEALTH_KEY) → `perf_birthdays` (replace-all) → app reads via Supabase.

## Test locally
`python3 -m http.server 8790 -d public` (launch config "performance"). Functions don't run locally;
the calendar box shows a placeholder when Supabase isn't configured.
