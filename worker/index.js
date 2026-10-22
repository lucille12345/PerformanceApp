/* Performance — Cloudflare Worker.
   Serves the app (the public/ folder) and the two online helpers:
     GET  /api/calendar — today's events from your calendar links
     POST /api/health   — the nightly Santé numbers from the iPhone Shortcut */
import { onRequestGet as calendar } from './calendar.js';
import { onRequestPost as health } from './health.js';
import { json } from './http.js';

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname === '/api/calendar' && request.method === 'GET') return calendar({ request, env });
    if (pathname === '/api/health' && request.method === 'POST') return health({ request, env });
    // Which settings this version can see (yes/no only, never the values).
    if (pathname === '/api/status') {
      const names = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_SECRET_KEY', 'HEALTH_KEY', 'OWNER_USER_ID', 'CALENDAR_URLS', 'TIMEZONE'];
      return json(Object.fromEntries(names.map((n) => [n, Boolean(env[n])])));
    }
    if (pathname.startsWith('/api/')) return json({ error: 'not found' }, 404);
    return env.ASSETS.fetch(request);
  },
};
