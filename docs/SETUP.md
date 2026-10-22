# Putting Performance online — step by step

Everything here is **free, no card**. You do it once (about 30–40 minutes). After that, every
change goes live by itself when you push with GitHub Desktop, like #Foodie.

You'll set up four things, in this order:

1. **GitHub** — keeps the code (same as #Foodie)
2. **Supabase** — keeps your data and syncs phone ↔ computer
3. **Cloudflare** — puts the app online as a Worker (never sleeps, opens instantly)
4. **Your iPhone** — install the app, connect your calendar, and add the Santé Shortcut

---

## 1. GitHub

1. Open **GitHub Desktop** → **File → Add Local Repository…** → choose the
   `~/Work/claude/PerformanceApp` folder.
2. It will say it's not a repository yet → click **create a repository** → **Create Repository**.
3. Click **Publish repository**. Keep **"Keep this code private"** ticked → **Publish**.

## 2. Supabase

You can have 2 free projects; #Foodie uses one, so this will be your second.

1. Go to **supabase.com → Dashboard → New project**. Name it `performance`, choose a database
   password (save it in your password manager), region **West EU (Paris)** → **Create**.
2. When it's ready: **SQL Editor → New query**, paste everything in `supabase/schema.sql`,
   click **Run**. You should see "Success. No rows returned".
3. **Authentication → Sign In / Providers → Email**: turn **off "Confirm email"** → Save.
   (Otherwise you'd have to click a link in an email before your first sign-in.)
4. **Project Settings → API Keys**. Copy:
   - the **Project URL** (looks like `https://abcd1234.supabase.co`)
   - the **Publishable key** (starts with `sb_publishable_`)
   - the **Secret key** (starts with `sb_secret_`) — **never put this one in the code**,
     only in Cloudflare (step 3).
5. Open `public/config.js` and paste the URL and the publishable key between the quotes.
   Commit + push in GitHub Desktop.

> A free Supabase project pauses after **7 days without anyone opening the app**. Using it daily
> keeps it awake. If it ever pauses, open the Supabase dashboard and click **Restore** — nothing is lost.

## 3. Cloudflare

1. Go to **dash.cloudflare.com** and create a free account.
2. **Workers & Pages → Create → Import a repository** → connect GitHub → pick `PerformanceApp`.
   Name it `performance-app` (it must match `"name"` in `wrangler.jsonc`), leave the build command
   empty and the deploy command as `npx wrangler deploy` → **Deploy**.
3. The settings that aren't secret (Supabase URL, publishable key, time zone, your user ID) are in
   `wrangler.jsonc` in this folder. The **secrets** go in the dashboard: open the Worker →
   **Settings** → the **Variables and Secrets** section (NOT the one inside **Build**, which only exists
   while the site is being built) → **+ Add** → type **Secret**:

   | Name | Value |
   |---|---|
   | `SUPABASE_SECRET_KEY` | your Supabase secret key |
   | `HEALTH_KEY` | the long random key in `health-key.txt` in this folder (never uploaded to GitHub) |
   | `CALENDAR_URLS` | added in step 4.3 |

   Click **Deploy** / **Save**. To check what the app can see, open `/api/status` on your address:
   every setting should say `true`.
   The app's address is on the Worker's **Overview** page, like `https://performance-app.YOUR-NAME.workers.dev`.

## 4. Your iPhone and Mac

### 4.1 Install it

- **iPhone:** open your `workers.dev` address in **Safari** → **Create account** (email + a password
  of 8+ characters) → tap **Share** → **Add to Home Screen** → **Add**. Open it from the flame icon
  from now on.
- **Mac:** open the same address in **Safari** → sign in → **File → Add to Dock**.

### 4.2 Lock it to your account

1. Supabase → **Authentication → Users** → click your account → copy the **User UID**.
2. Paste it into `"OWNER_USER_ID"` in `wrangler.jsonc` (or send it to Claude), then commit + push.
3. Supabase → **Authentication → Sign In / Providers** → turn **off "Allow new users to sign up"**.

Now nobody else can create an account or read your calendar and Santé numbers.

### 4.3 Connect your calendar

The app reads your calendar through a private link to it.

- **iCloud calendar (Apple Calendar):** iPhone **Calendar** app → **Calendars** → tap **ⓘ** next
  to the calendar → turn on **Public Calendar** → **Share Link… → Copy**.
  Do this for each calendar you want on the Today page.
- **Google Calendar:** calendar.google.com on a computer → ⚙️ **Settings** → click the calendar →
  **Integrate calendar** → copy **Secret address in iCal format**.

Paste the links into **`CALENDAR_URLS`** in Cloudflare, separated by a space, then click **Deploy**.

> "Public" means anyone who has that exact link can see the calendar. The link is long and random,
> it's only stored in Cloudflare, and you can turn it off any time (which also changes it).
> New events appear in the app within about 5 minutes.

### 4.4 The Santé Shortcut

A website can't read Santé, so a Shortcut on your iPhone sends yesterday's numbers to the app once a day.

Open the **Shortcuts** app → **+** → name it **Send Santé**. Add these actions:

1. **Find Health Samples** — Type **Steps**, Start Date **is yesterday**, tap **Show More** → Group By **Day**.
   Then **Get Details of Health Samples** → **Value**. Long-press the result → **Rename** → `Steps`.
2. Same again for **Walking + Running Distance** → rename `Distance`.
3. Same again for **Active Energy** → `Energy`.
4. Same again for **Resting Heart Rate** → `Resting`.
5. Same again for **Flights Climbed** → `Flights`.
6. **Find Health Samples** — Type **Sleep Analysis**, Start Date **is yesterday**, Value **is Asleep**.
   Then **Get Details of Health Samples** → **Duration**, then **Calculate Statistics** → **Sum** → rename `Sleep`.
7. **Adjust Date** → subtract **1 day** from **Current Date**, then **Format Date** → Custom → `yyyy-MM-dd`
   → rename `Day`.
8. **Get Contents of URL** — `https://performance-app.llucillespam.workers.dev/api/health`
   - Method **POST**
   - Headers: `Authorization` = `Bearer ` followed by your `HEALTH_KEY`
   - Request Body **JSON**, with these keys (each one a Text set to the matching variable):
     `day` → Day, `steps` → Steps, `distance` → Distance, `energy` → Energy,
     `resting_hr` → Resting, `sleep` → Sleep, `flights` → Flights
9. Tap ▶ once to test. It should answer `{"saved":"2026-…"}` and allow access to Santé when asked.

Then make it run by itself: **Automation** tab → **+** → **Time of Day** → pick a time you're
usually using your phone (e.g. **12:30**), **Daily** → **Run Immediately** → choose **Send Santé**.

> iOS can't read Santé while the iPhone is locked. If a day's numbers are missing, just run the
> Shortcut by hand. A missed day doesn't distort the averages, because the averages only count days
> that arrived.

### 4.5 Birthdays from Contacts

A website can't open Contacts either, so a second Shortcut sends the list of birthdays once a week.
(First time only: run `supabase/birthdays.sql` in Supabase's SQL Editor.)

**Shortcuts** app → **+** → name it **Send birthdays**:

1. **Find Contacts**: no filter, turn **Limit** off (so it finds all of them).
2. **Repeat with Each** (item in Contacts). Inside the repeat:
   1. **Get Details of Contacts** → **Birthday** (of *Repeat Item*).
   2. **If** *Birthday* **has any value**:
      - **Format Date** → *Birthday* → Custom → `yyyy-MM-dd`
      - **Text** → *Repeat Item* (tap it → **Name**), then type `|`, then *Formatted Date*
        (looks like `Marie Dupont|1998-12-08`)
      - **Add to Variable** → name `Lines`
   3. **End If**
3. After **End Repeat**: **Combine Text** → *Lines* → with **New Lines**.
4. **Get Contents of URL**: `https://performance-app.llucillespam.workers.dev/api/birthdays`
   - Method **POST**, Headers `Authorization` = `Bearer ` + your `HEALTH_KEY`
   - Request Body **JSON**: key `list` → *Combined Text*
5. Tap ▶. It should answer `{"saved":…}` with the number of birthdays, and ask once for access to Contacts.

**Automation** tab → **+** → **Time of Day** → **Weekly**, Sunday 12:00 → **Run Immediately** →
**Send birthdays**. New contacts appear in the app after the next Sunday (or run it by hand).

> Names and birthdays are stored in your own Supabase database, readable only by your account.
> Contacts saved without a birth year show without an age.

---

## If something doesn't work

- **Stuck on "Syncing"** → check `public/config.js` has the right URL and publishable key.
- **Calendar says "No calendar access"** → `OWNER_USER_ID` doesn't match your account, or a link in
  `CALENDAR_URLS` is wrong.
- **Shortcut answers `unauthorized`** → the `HEALTH_KEY` in the Shortcut and in Cloudflare differ
  (check there's exactly one space after `Bearer`).
- **An update doesn't show up** → close and reopen the app twice. It always opens instantly from the
  copy saved on the phone and quietly fetches the new version for next time.
