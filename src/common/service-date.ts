/**
 * Centralized IST (Asia/Kolkata) service-date logic.
 *
 * The "menu day" MUST roll over at IST midnight — not UTC midnight (which is
 * 05:30 IST) and not the server's local midnight (prod runs UTC inside Docker).
 * Every place that needs "today" for daily availability, cooking status, or
 * operating hours goes through here so the rollover is identical across order
 * placement, radius discovery, and the daily-menu screen.
 *
 * IST is a fixed +05:30 offset with no DST, so we shift-then-read-UTC instead
 * of pulling in a timezone library.
 */

const IST_OFFSET_MIN = 330; // +05:30, no DST

/**
 * The given instant re-expressed as a Date whose UTC fields carry the IST
 * wall-clock year/month/day/hour/minute. Internal helper — never persist this
 * value; it is a shifted instant, not a real UTC time.
 */
function istParts(now: Date): Date {
  return new Date(now.getTime() + IST_OFFSET_MIN * 60_000);
}

/**
 * "Today" in IST as a UTC-midnight Date — the canonical `serviceDate` value.
 * Prisma stores `@db.Date` columns as UTC-midnight, so this matches exactly how
 * availability / daily-status rows are keyed and read everywhere else.
 */
export function istServiceDate(now: Date = new Date()): Date {
  const ist = istParts(now);
  return new Date(
    Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()),
  );
}

/** IST day-of-week (0=Sun … 6=Sat) for operating-hours lookups. */
export function istDayOfWeek(now: Date = new Date()): number {
  return istParts(now).getUTCDay();
}

/** Current IST wall-clock time as "HH:MM" for operating-hours comparisons. */
export function istTimeHHMM(now: Date = new Date()): string {
  const ist = istParts(now);
  const h = String(ist.getUTCHours()).padStart(2, '0');
  const m = String(ist.getUTCMinutes()).padStart(2, '0');
  return `${h}:${m}`;
}

/** Format a UTC-midnight service Date back to "YYYY-MM-DD". */
export function formatServiceDate(d: Date): string {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** "Today" in IST as a "YYYY-MM-DD" string. */
export function istTodayStr(now: Date = new Date()): string {
  return formatServiceDate(istServiceDate(now));
}

/**
 * Parse an incoming "YYYY-MM-DD" (sent by the apps) to the UTC-midnight Date
 * used as `serviceDate`. Throws on a malformed string. Only the date part is
 * honoured, so a caller can't smuggle a time/zone in to shift the day.
 */
export function parseServiceDate(dateStr: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  if (!m) {
    throw new Error(`Invalid service date "${dateStr}" (expected YYYY-MM-DD).`);
  }
  const [, y, mo, d] = m;
  return new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d)));
}
