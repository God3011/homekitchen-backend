import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kitchen_provider.dart';

/// Earnings summary for a period. All money in integer paise. "Earned" means an
/// order reached `completed`; pending balance is lifetime net minus payouts.
class EarningsSummary {
  final String period;
  final int grossPaise;
  final int orderCount;
  final int feeDays;
  final int feesPaise;
  final int netEarningsPaise;
  final int pendingBalancePaise;

  const EarningsSummary({
    required this.period,
    required this.grossPaise,
    required this.orderCount,
    required this.feeDays,
    required this.feesPaise,
    required this.netEarningsPaise,
    required this.pendingBalancePaise,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
        period: j['period'] as String,
        grossPaise: j['grossPaise'] as int,
        orderCount: j['orderCount'] as int,
        feeDays: (j['feeDays'] as int?) ?? 0,
        feesPaise: j['feesPaise'] as int,
        netEarningsPaise: j['netEarningsPaise'] as int,
        pendingBalancePaise: j['pendingBalancePaise'] as int,
      );
}

/// A recorded payout (manual UPI transfer logged by ops).
class Payout {
  final String id;
  final int amountPaise;
  final String payoutDate; // ISO date
  final String? note;

  const Payout({
    required this.id,
    required this.amountPaise,
    required this.payoutDate,
    this.note,
  });

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: j['id'] as String,
        amountPaise: j['amountPaise'] as int,
        payoutDate: j['payoutDate'] as String,
        note: j['note'] as String?,
      );
}

/// Earnings for a period ('today' | 'week' | 'month' | 'all').
final earningsProvider =
    FutureProvider.autoDispose.family<EarningsSummary, String>((ref, period) async {
  final api = ref.watch(apiClientProvider);
  final data =
      await api.get('/kitchens/me/earnings', queryParams: {'period': period});
  return EarningsSummary.fromJson(data);
});

/// Payout history, newest first.
final payoutsProvider =
    FutureProvider.autoDispose<List<Payout>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/kitchens/me/payouts');
  final items = (data['items'] as List?) ?? const [];
  return items
      .map((e) => Payout.fromJson(e as Map<String, dynamic>))
      .toList();
});
