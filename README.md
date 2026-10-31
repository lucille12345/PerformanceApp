# 🔥 Performance

Your daily schedule, streak, notes, training and stats. It's a web app you add to your iPhone
home screen and your Mac's Dock: it opens instantly, never expires, and syncs between your
devices through Supabase.

**First time putting it online:** follow [`docs/SETUP.md`](docs/SETUP.md).

## Run it on your computer (for testing)

```
cd ~/Work/claude/PerformanceApp
python3 -m http.server 8790 -d public
```

Then open **http://localhost:8790**. With `public/config.js` left empty it keeps everything in that
browser only. Calendar and Santé need the online version.

## What's in this folder

| Thing | What it is |
|---|---|
| `public/` | **The app itself**: what Cloudflare puts online |
| `public/logic.js` | The rules: 3am reset, a plan per day, streak, weekly hours, monthly stats, 3-month cleanup, sync merging |
| `data/birthdays.txt` | Birthdays shown in the calendar: one `Name \| date` per line |
| `public/config.js` | Supabase address + publishable key (safe to be public) |
| `worker/` | The Cloudflare Worker: serves `public/` plus two small online helpers: `calendar` (reads your calendar link) and `health` (receives Santé numbers) |
| `wrangler.jsonc` | Cloudflare settings (Worker name, which folder is the site) |
| `supabase/schema.sql` | The database tables (paste once into Supabase) |
| `docs/SETUP.md` | Step-by-step setup |
| `native/` | The earlier iPhone/Mac Xcode version, kept for reference, not used |

## Publishing a change

Commit and push with **GitHub Desktop**. Cloudflare updates the site in about a minute. The app on
your phone picks it up the next time you open it.
