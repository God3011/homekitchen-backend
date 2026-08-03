import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { KitchensService } from '../kitchens/kitchens.service';
import { RequestUser } from '../auth/decorators';

/**
 * Customer-facing fuzzy search. Reuses the discovery endpoint's exact
 * radius/serviceable candidate set (so search can NEVER surface a kitchen
 * outside the customer's serviceable area) and then ranks those candidates by
 * Postgres pg_trgm similarity against the kitchen name and its dish names.
 *
 * Matching + scoring happen in Postgres (trigram `%` operator + `similarity()`,
 * backed by the GIN trgm indexes on `kitchens.kitchen_name` and
 * `menu_items.name`) — not naive ILIKE — so mild typos still match
 * ("biriyani" → "Biryani", "paner" → "Paneer").
 */
@Injectable()
export class SearchService {
  // Lenient trigram threshold: mild typos still match, without drowning in noise.
  private static readonly SIMILARITY_THRESHOLD = 0.2;
  // Similarity scores within this delta are treated as a tie → distance breaks it.
  private static readonly SCORE_TIE_DELTA = 0.05;

  constructor(
    private readonly prisma: PrismaService,
    private readonly kitchens: KitchensService,
  ) {}

  async search(
    user: RequestUser,
    opts: { q: string; lat: number; lng: number; radiusM?: number },
  ) {
    const q = opts.q.trim();

    // Reuse discovery for the identical radius/serviceable candidate set and the
    // same three-state envelope shape the app already renders.
    const discovery = await this.kitchens.list(user, {
      lat: opts.lat,
      lng: opts.lng,
      radiusM: opts.radiusM,
    });

    // Blank query → behave exactly like discovery.
    if (q.length === 0) return { ...discovery, query: q };

    const cards = discovery.kitchens;
    if (cards.length === 0) {
      return { state: 'none_in_radius', kitchens: [], query: q };
    }

    // Score ONLY the in-radius candidates with pg_trgm. set_limit tunes the `%`
    // operator's threshold; both run on one connection via the transaction.
    const candidateIds = cards.map((c) => c.id);
    const scored = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(
        `SELECT set_limit(${SearchService.SIMILARITY_THRESHOLD})`,
      );
      return tx.$queryRaw<{ id: string; score: number }[]>`
        SELECT k.id::text AS id,
               GREATEST(
                 similarity(k.kitchen_name, ${q}),
                 COALESCE(MAX(similarity(mi.name, ${q})), 0)
               )::float8 AS score
        FROM kitchens k
        LEFT JOIN menu_items mi
          ON mi.kitchen_id = k.id AND mi.is_active = true
        WHERE k.id IN (${Prisma.join(candidateIds)})
          AND (k.kitchen_name % ${q} OR mi.name % ${q})
        GROUP BY k.id
        ORDER BY score DESC
      `;
    });

    const scoreById = new Map(scored.map((r) => [r.id, r.score]));
    const matched = cards
      .filter((c) => scoreById.has(c.id))
      .map((c) => ({ card: c, score: scoreById.get(c.id) ?? 0 }));

    // Rank by trigram similarity; when scores are close, the nearer kitchen wins.
    matched.sort((a, b) => {
      if (Math.abs(a.score - b.score) > SearchService.SCORE_TIE_DELTA) {
        return b.score - a.score;
      }
      return (a.card.distanceM ?? Infinity) - (b.card.distanceM ?? Infinity);
    });

    const kitchens = matched.map((m) => m.card);
    const state = kitchens.some((k) => k.serviceable)
      ? 'serviceable'
      : kitchens.length > 0
        ? 'dormant_only'
        : 'none_in_radius';

    return { state, kitchens, query: q };
  }
}
