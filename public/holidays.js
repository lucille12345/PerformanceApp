/* ============================================================================
   Performance — celebration days, worked out on the device (nothing to set up)
   French public holidays and fêtes, Catholic, Jewish, American and worldwide.
   Jewish dates use the Hebrew calendar built into the browser; Jewish holidays
   start the evening before the date shown.
   ============================================================================ */

export const KINDS = {
  fr: { label: 'Jour férié', color: '#1EA7E1' },
  fete: { label: 'Fête', color: '#FF8A3D' },
  catholic: { label: 'Catholique', color: '#E8C547' },
  jewish: { label: 'Jewish', color: '#7FA7FF' },
  us: { label: 'USA', color: '#FF6B6B' },
  world: { label: 'World', color: '#3DDC84' },
};

const md = (d) => `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
const same = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

/** Easter Sunday (Gregorian), Meeus/Jones/Butcher algorithm. */
export function easter(y) {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
  const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(y, month - 1, day);
}

/** The n-th given weekday of a month (n = -1 → last). weekday: 0 = Sunday. */
function nthWeekday(y, month, weekday, n) {
  if (n > 0) {
    const first = new Date(y, month, 1);
    return new Date(y, month, 1 + ((weekday - first.getDay() + 7) % 7) + (n - 1) * 7);
  }
  const last = new Date(y, month + 1, 0);
  return new Date(y, month, last.getDate() - ((last.getDay() - weekday + 7) % 7));
}

// Chinese New Year (lunar), from published tables.
const CNY = { 2025: '01-29', 2026: '02-17', 2027: '02-06', 2028: '01-26', 2029: '02-13', 2030: '02-03',
  2031: '01-23', 2032: '02-11', 2033: '01-31', 2034: '02-19', 2035: '02-08', 2036: '01-28' };

const FIXED = {
  '01-01': [['Jour de l’An', 'fr']],
  '01-06': [['Épiphanie · galette des rois', 'catholic']],
  '02-02': [['Chandeleur', 'fete']],
  '02-14': [['Saint-Valentin', 'fete']],
  '03-08': [['International Women’s Day', 'world']],
  '03-17': [['St. Patrick’s Day', 'world']],
  '04-01': [['Poisson d’avril', 'fete']],
  '05-01': [['Fête du Travail', 'fr']],
  '05-08': [['Victoire 1945', 'fr']],
  '06-21': [['Fête de la musique', 'fete']],
  '07-04': [['Independence Day', 'us']],
  '07-14': [['Fête nationale', 'fr']],
  '08-15': [['Assomption', 'fr']],
  '10-31': [['Halloween', 'world']],
  '11-01': [['Toussaint', 'fr']],
  '11-11': [['Armistice 1918', 'fr']],
  '12-08': [['Immaculée Conception', 'catholic']],
  '12-24': [['Réveillon de Noël', 'fete']],
  '12-25': [['Noël', 'fr']],
  '12-31': [['Saint-Sylvestre', 'fete']],
};

const hebrewFmt = (() => {
  try { return new Intl.DateTimeFormat('en-u-ca-hebrew', { month: 'long', day: 'numeric' }); } catch { return null; }
})();
function hebrew(d) {
  if (!hebrewFmt) return null;
  const parts = hebrewFmt.formatToParts(new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12));
  return { month: parts.find((p) => p.type === 'month')?.value, day: Number(parts.find((p) => p.type === 'day')?.value) };
}
function jewishOn(d) {
  const h = hebrew(d);
  if (!h) return [];
  const out = [];
  const is = (m, day) => h.month === m && h.day === day;
  if (is('Tishri', 1) || is('Tishri', 2)) out.push('Rosh Hashanah');
  if (is('Tishri', 10)) out.push('Yom Kippur');
  if (is('Tishri', 15)) out.push('Sukkot');
  if (is('Tishri', 23)) out.push('Simchat Torah');
  // Hanukkah: 8 days from 25 Kislev.
  for (let i = 0; i < 8; i++) {
    const s = hebrew(addDays(d, -i));
    if (s.month === 'Kislev' && s.day === 25) { out.push(`Hanukkah · day ${i + 1}`); break; }
  }
  // Purim: 14 Adar, or 14 Adar II in a leap year.
  if (h.day === 14 && (h.month === 'Adar II' || (h.month === 'Adar' && hebrew(addDays(d, 30)).month !== 'Adar II'))) out.push('Purim');
  if (is('Nisan', 15)) out.push('Pesach');
  if (is('Sivan', 6)) out.push('Shavuot');
  return out.map((n) => [n, 'jewish']);
}

/** Everything celebrated on this day: [{ name, kind }] */
export function holidaysOn(d) {
  const y = d.getFullYear();
  const list = [...(FIXED[md(d)] ?? [])];
  const e = easter(y);
  const rel = [
    [-47, 'Mardi gras', 'fete'], [-46, 'Mercredi des Cendres', 'catholic'], [-7, 'Rameaux', 'catholic'],
    [-2, 'Vendredi saint', 'catholic'], [0, 'Pâques', 'catholic'], [1, 'Lundi de Pâques', 'fr'],
    [39, 'Ascension', 'fr'], [49, 'Pentecôte', 'catholic'], [50, 'Lundi de Pentecôte', 'fr'],
  ];
  for (const [off, name, kind] of rel) if (same(d, addDays(e, off))) list.push([name, kind]);

  // Fête des mères: last Sunday of May, moved to the first Sunday of June when it's Pentecost.
  let mothers = nthWeekday(y, 4, 0, -1);
  if (same(mothers, addDays(e, 49))) mothers = addDays(mothers, 7);
  if (same(d, mothers)) list.push(['Fête des mères', 'fete']);
  if (same(d, nthWeekday(y, 5, 0, 3))) list.push(['Fête des pères', 'fete']);
  if (same(d, nthWeekday(y, 10, 4, 3))) list.push(['Beaujolais nouveau', 'fete']);

  if (same(d, nthWeekday(y, 0, 1, 3))) list.push(['Martin Luther King Jr. Day', 'us']);
  if (same(d, nthWeekday(y, 4, 1, -1))) list.push(['Memorial Day', 'us']);
  if (same(d, nthWeekday(y, 8, 1, 1))) list.push(['Labor Day', 'us']);
  if (same(d, nthWeekday(y, 10, 4, 4))) list.push(['Thanksgiving', 'us']);

  if (CNY[y] === md(d)) list.push(['Chinese New Year', 'world']);
  list.push(...jewishOn(d));
  return list.map(([name, kind]) => ({ name, kind }));
}
