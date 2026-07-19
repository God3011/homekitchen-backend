import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/earnings_provider.dart';

String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

const _periods = <String, String>{
  'today': 'Today',
  'week': 'Week',
  'month': 'Month',
  'all': 'All',
};

String _humanDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}

/// Kitchen finance dashboard: balance + history + next payout date.
/// v1 payouts are scheduled (settled weekly by ops); there is no self-serve
/// withdraw — see the TODO(v2) marker below.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  String _period = 'today';

  @override
  void initState() {
    super.initState();
    _trackView(_period);
  }

  void _trackView(String period) {
    final kitchenId = ref.read(kitchenProfileProvider).valueOrNull?.id ?? '';
    trackEvent('earnings_viewed', {
      'kitchen_id': kitchenId,
      'period_viewed': period,
    });
  }

  void _selectPeriod(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _trackView(period);
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(earningsProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningsProvider(_period));
          ref.invalidate(payoutsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PeriodTabs(selected: _period, onSelect: _selectPeriod),
            const SizedBox(height: 16),
            earnings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorBlock(
                message: '$e',
                onRetry: () => ref.invalidate(earningsProvider(_period)),
              ),
              data: (s) => Column(
                children: [
                  _PendingBalanceCard(pendingPaise: s.pendingBalancePaise),
                  const SizedBox(height: 16),
                  _SummaryCard(summary: s),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Payout history',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const _PayoutHistory(),
          ],
        ),
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _periods.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelect(entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Prominent balance card — the "how much am I owed" answer up top.
class _PendingBalanceCard extends StatelessWidget {
  const _PendingBalanceCard({required this.pendingPaise});
  final int pendingPaise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance_wallet,
                  color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text('Pending Balance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(_rupees(pendingPaise),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event, size: 16, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Payouts are settled weekly — next payout Monday',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ]),
            // TODO(v2): self-serve withdrawals — a "Withdraw" button + bank
            // details collection (RazorpayX) goes here. v1 is scheduled payouts.
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Gross earnings', _rupees(summary.grossPaise)),
            const Divider(height: 20),
            _row(context, 'Completed orders', '${summary.orderCount}'),
            const Divider(height: 20),
            _row(context, 'Platform fees',
                '− ${_rupees(summary.feesPaise)}'),
            const Divider(height: 20),
            _row(
              context,
              'Net earnings',
              _rupees(summary.netEarningsPaise),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _PayoutHistory extends ConsumerWidget {
  const _PayoutHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(payoutsProvider);
    return payouts.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorBlock(
        message: '$e',
        onRetry: () => ref.invalidate(payoutsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.history,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text(
                    'No payouts yet — your first payout arrives after your '
                    'first completed orders.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final p in list)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.south_west, color: Colors.green),
                  title: Text(_rupees(p.amountPaise),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_humanDate(p.payoutDate)),
                  trailing: p.note != null
                      ? SizedBox(
                          width: 120,
                          child: Text(p.note!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('Could not load earnings.\n$message',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
