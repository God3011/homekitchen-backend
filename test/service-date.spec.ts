/**
 * Unit tests for the centralized IST service-date helper.
 *
 * No database / Nest app — pure functions. These pin down the ONE rule the
 * whole daily-menu feature rests on: the service day rolls over at IST midnight
 * (18:30 UTC), never at UTC midnight (05:30 IST) and never at the server's
 * local midnight. Assertions read the result via UTC getters, so they are
 * independent of the machine timezone the test runs in.
 */

import {
  formatServiceDate,
  istDayOfWeek,
  istServiceDate,
  istTimeHHMM,
  istTodayStr,
  parseServiceDate,
} from '../src/common/service-date';

describe('service-date (IST helper)', () => {
  describe('istServiceDate rolls over at IST midnight (18:30 UTC)', () => {
    it('23:59 IST is still the same IST day', () => {
      // 2026-07-19T18:29:00Z → 2026-07-19 23:59 IST
      const d = istServiceDate(new Date('2026-07-19T18:29:00Z'));
      expect(formatServiceDate(d)).toBe('2026-07-19');
    });

    it('00:00 IST (18:30 UTC) is the NEXT IST day', () => {
      // 2026-07-19T18:30:00Z → 2026-07-20 00:00 IST
      const d = istServiceDate(new Date('2026-07-19T18:30:00Z'));
      expect(formatServiceDate(d)).toBe('2026-07-20');
    });

    it('does NOT roll at UTC midnight — 22:00 UTC is already the next IST day', () => {
      // 2026-07-19T22:00:00Z → 2026-07-20 03:30 IST. A UTC-based "today" would
      // wrongly say 2026-07-19.
      const d = istServiceDate(new Date('2026-07-19T22:00:00Z'));
      expect(formatServiceDate(d)).toBe('2026-07-20');
    });

    it('05:30 IST (00:00 UTC) is still the same IST calendar day', () => {
      const d = istServiceDate(new Date('2026-07-19T00:00:00Z'));
      expect(formatServiceDate(d)).toBe('2026-07-19');
    });

    it('returns a UTC-midnight Date (matches Prisma @db.Date storage)', () => {
      const d = istServiceDate(new Date('2026-07-19T12:00:00Z'));
      expect(d.getUTCHours()).toBe(0);
      expect(d.getUTCMinutes()).toBe(0);
      expect(d.getUTCSeconds()).toBe(0);
    });
  });

  describe('istDayOfWeek / istTimeHHMM track IST wall clock', () => {
    it('reports Sunday 23:59 just before the IST midnight boundary', () => {
      // 2026-07-19 is a Sunday.
      const at = new Date('2026-07-19T18:29:00Z');
      expect(istDayOfWeek(at)).toBe(0); // Sun
      expect(istTimeHHMM(at)).toBe('23:59');
    });

    it('reports Monday 00:00 right at the IST midnight boundary', () => {
      const at = new Date('2026-07-19T18:30:00Z');
      expect(istDayOfWeek(at)).toBe(1); // Mon
      expect(istTimeHHMM(at)).toBe('00:00');
    });
  });

  describe('parseServiceDate / formatServiceDate', () => {
    it('round-trips a YYYY-MM-DD string to UTC-midnight and back', () => {
      const d = parseServiceDate('2026-07-19');
      expect(d.getUTCFullYear()).toBe(2026);
      expect(d.getUTCMonth()).toBe(6); // 0-based July
      expect(d.getUTCDate()).toBe(19);
      expect(d.getUTCHours()).toBe(0);
      expect(formatServiceDate(d)).toBe('2026-07-19');
    });

    it('rejects a malformed date string', () => {
      expect(() => parseServiceDate('19-07-2026')).toThrow();
      expect(() => parseServiceDate('2026-07-19T10:00:00Z')).toThrow();
      expect(() => parseServiceDate('not-a-date')).toThrow();
    });
  });

  it('istTodayStr matches formatServiceDate(istServiceDate())', () => {
    const now = new Date();
    expect(istTodayStr(now)).toBe(formatServiceDate(istServiceDate(now)));
  });
});
