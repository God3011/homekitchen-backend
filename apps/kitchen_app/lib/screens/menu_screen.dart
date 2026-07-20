import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../providers/daily_menu_provider.dart';
import '../providers/kitchen_provider.dart';

// ── date helpers (seller phones run in IST, so local == service day) ─────────
String _two(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _humanDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

/// The date the Menu screen is currently viewing.
final menuDateProvider = StateProvider<DateTime>((_) => _today());

/// Daily menu: pick a date, stage stock edits locally, save in one batch.
/// Today is editable; past dates are read-only history.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(menuDateProvider);
    final dateStr = _fmt(selected);
    final state = ref.watch(dailyMenuProvider(dateStr));
    final notifier = ref.read(dailyMenuProvider(dateStr).notifier);

    return PopScope(
      canPop: !state.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !state.dirty) return;
        final discard = await _confirmDiscard(context);
        if (discard == true) notifier.discard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Menu'),
          actions: [
            if (state.dirty && !state.readOnly)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(child: _UnsavedChip()),
              ),
          ],
        ),
        // Save bar sits at the bottom of the body Column (not a nested
        // bottomNavigationBar). Its buttons must be flex children — see _SaveBar.
        body: Column(
          children: [
            _DateChips(selected: selected),
            const Divider(height: 1),
            Expanded(child: _Body(dateStr: dateStr)),
            if (state.dirty && !state.readOnly) _SaveBar(dateStr: dateStr),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmDiscard(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
            'You have edits that haven\'t been saved. Leave without saving?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

class _UnsavedChip extends StatelessWidget {
  const _UnsavedChip();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit, size: 14, color: scheme.onTertiaryContainer),
        const SizedBox(width: 4),
        Text('Unsaved',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onTertiaryContainer)),
      ]),
    );
  }
}

// ── Date selector ────────────────────────────────────────────────────────────
class _DateChips extends ConsumerWidget {
  const _DateChips({required this.selected});
  final DateTime selected;

  Future<void> _pick(BuildContext context, WidgetRef ref, DateTime target) async {
    final dateStr = _fmt(ref.read(menuDateProvider));
    final state = ref.read(dailyMenuProvider(dateStr));
    if (state.dirty) {
      final discard = await _confirmDiscard(context);
      if (discard != true) return;
      ref.read(dailyMenuProvider(dateStr).notifier).discard();
    }
    ref.read(menuDateProvider.notifier).state = target;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _today();
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = selected == today;
    final isYesterday = selected == yesterday;
    final isOther = !isToday && !isYesterday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: isToday,
          onSelected: (_) => _pick(context, ref, today),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: isYesterday,
          onSelected: (_) => _pick(context, ref, yesterday),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(isOther ? _humanDate(selected) : 'Select date'),
          selected: isOther,
          onSelected: (_) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: today.subtract(const Duration(days: 90)),
              lastDate: today, // no future — v1 is same-day
            );
            if (picked != null && context.mounted) {
              await _pick(context, ref, DateTime(picked.year, picked.month, picked.day));
            }
          },
        ),
      ]),
    );
  }
}

// ── Body: loading / error / read-only / editable ─────────────────────────────
class _Body extends ConsumerWidget {
  const _Body({required this.dateStr});
  final String dateStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyMenuProvider(dateStr));
    final notifier = ref.read(dailyMenuProvider(dateStr).notifier);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Failed to load menu.\n${state.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: notifier.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    if (state.readOnly) return _PastView(state: state);
    return _EditableView(dateStr: dateStr);
  }
}

// ── Past date: read-only summary ─────────────────────────────────────────────
class _PastView extends StatelessWidget {
  const _PastView({required this.state});
  final DailyMenuState state;

  @override
  Widget build(BuildContext context) {
    final served = state.working.where((d) => d.onMenu).toList();
    if (served.isEmpty) {
      return const _EmptyHint(
        icon: Icons.history,
        title: 'Nothing on the menu that day',
        subtitle: 'No dishes were offered on this date.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ReadOnlyBanner(),
        const SizedBox(height: 12),
        for (final d in served)
          Card(
            child: ListTile(
              leading: _Thumb(url: d.photoUrl),
              title: Text(d.name),
              subtitle: Text(
                '${_rupees(d.pricePaise)}  ·  '
                '${d.platesSold} sold of ${d.platesTotal}  ·  '
                '${d.platesRemaining} left',
              ),
              trailing: !d.isAvailable
                  ? const Text('Stopped',
                      style: TextStyle(fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Past menus are view-only.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

// ── Today: editable two-section layout ───────────────────────────────────────
class _EditableView extends ConsumerWidget {
  const _EditableView({required this.dateStr});
  final String dateStr;

  Future<void> _newDish(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const _NewDishScreen()),
    );
    if (created == null) return;
    ref.read(dailyMenuProvider(dateStr).notifier).addNewlyCreatedDish(
          menuItemId: created['id'] as String,
          name: created['name'] as String,
          pricePaise: created['pricePaise'] as int,
          photoUrl: created['photoUrl'] as String?,
          isVeg: created['isVeg'] as bool? ?? true,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyMenuProvider(dateStr));

    if (!state.hasCatalog) {
      return _EmptyHint(
        icon: Icons.restaurant_menu,
        title: 'No dishes yet',
        subtitle: 'Add your first dish to start today\'s menu.',
        action: FilledButton.icon(
          onPressed: () => _newDish(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New dish'),
        ),
      );
    }

    final onMenu = state.onMenu;
    final offMenu = state.offMenu;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionHeader('On today\'s menu', count: onMenu.length),
        if (onMenu.isEmpty)
          const _InlineHint(
              'Nothing on today\'s menu yet — add from your dishes below.'),
        for (final d in onMenu) _OnMenuCard(dateStr: dateStr, dish: d),
        const SizedBox(height: 20),
        _SectionHeader('Add from your dishes', count: offMenu.length),
        if (offMenu.isEmpty)
          const _InlineHint('All your dishes are on today\'s menu.'),
        for (final d in offMenu) _OffMenuCard(dateStr: dateStr, dish: d),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _newDish(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New dish'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('$title  ($count)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _InlineHint extends StatelessWidget {
  const _InlineHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}

// ── On-menu card: stepper + sold info + sold-out toggle + remove ─────────────
class _OnMenuCard extends ConsumerWidget {
  const _OnMenuCard({required this.dateStr, required this.dish});
  final String dateStr;
  final DailyDish dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyMenuProvider(dateStr).notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Thumb(url: dish.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VegBadge(isVeg: dish.isVeg, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(dish.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ],
                    ),
                    Text(_rupees(dish.pricePaise),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _EditDishDetailsScreen(dateStr: dateStr, dish: dish),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit dish details')),
                ],
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _StockStepper(
                value: dish.platesTotal,
                onChanged: (v) => notifier.setPlates(dish.menuItemId, v),
                onDec: () => notifier.decPlates(dish.menuItemId),
                onInc: () => notifier.incPlates(dish.menuItemId),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${dish.platesRemaining} left · ${dish.platesSold} sold',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 13),
                ),
              ),
            ]),
            Row(children: [
              Switch(
                value: dish.isAvailable,
                onChanged: (v) => notifier.setAvailable(dish.menuItemId, v),
              ),
              Text(dish.isAvailable ? 'Selling' : 'Sold out',
                  style: TextStyle(
                      color: dish.isAvailable
                          ? null
                          : Theme.of(context).colorScheme.error)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Off-menu card: greyed, quick-add ─────────────────────────────────────────
class _OffMenuCard extends ConsumerWidget {
  const _OffMenuCard({required this.dateStr, required this.dish});
  final String dateStr;
  final DailyDish dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyMenuProvider(dateStr).notifier);
    return Opacity(
      opacity: 0.65,
      // A custom Row rather than ListTile: ListTile runs an intrinsic-width pass
      // that an Expanded title makes infinite (crashes under semantics). This
      // gives the same look with full layout control.
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Thumb(url: dish.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VegBadge(isVeg: dish.isVeg, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(dish.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_rupees(dish.pricePaise),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                // Constrain: the app theme sets button minWidth = infinity,
                // which would crash as a non-flex Row child.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => notifier.quickAdd(dish.menuItemId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Quick add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sticky save bar ──────────────────────────────────────────────────────────
class _SaveBar extends ConsumerWidget {
  const _SaveBar({required this.dateStr});
  final String dateStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyMenuProvider(dateStr));
    final notifier = ref.read(dailyMenuProvider(dateStr).notifier);
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          // Both buttons are Expanded: the app theme sets button
          // minimumSize.width = infinity (full-width buttons), which demands
          // infinite width if placed as a NON-flex Row child (a Row measures
          // non-flex children unbounded). Flex children get a tight bounded
          // width, so the theme's infinite min is clamped and layout is safe.
          child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: state.saving ? null : notifier.discard,
              child: const Text('Discard'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: state.saving
                  ? null
                  : () async {
                      try {
                        await notifier.save();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Menu saved')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      }
                    },
              child: state.saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
          ]),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ───────────────────────────────────────────────────
class _StockStepper extends StatelessWidget {
  const _StockStepper({
    required this.value,
    required this.onChanged,
    required this.onDec,
    required this.onInc,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onDec;
  final VoidCallback onInc;

  Future<void> _editExact(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set plates'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Plates'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value > 0 ? onDec : null,
          icon: const Icon(Icons.remove),
        ),
        GestureDetector(
          onTap: () => _editExact(context),
          child: SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onInc,
          icon: const Icon(Icons.add),
        ),
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url != null
            ? Image.network(url!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ThumbFallback())
            : const _ThumbFallback(),
      );
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade200,
        child: const Icon(Icons.restaurant, color: Colors.grey, size: 22),
      );
}

/// Veg / Non-veg picker used when creating and editing a dish. Two tiles, each
/// with the standard marker; the selected one is highlighted.
class _VegSelector extends StatelessWidget {
  const _VegSelector({required this.isVeg, required this.onChanged});
  final bool isVeg;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _option(context, veg: true, selected: isVeg)),
        const SizedBox(width: 12),
        Expanded(child: _option(context, veg: false, selected: !isVeg)),
      ],
    );
  }

  Widget _option(BuildContext context,
      {required bool veg, required bool selected}) {
    final color =
        veg ? const Color(0xFF5C8570) : const Color(0xFFB4472F);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(veg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VegBadge(isVeg: veg, size: 18),
            const SizedBox(width: 8),
            Text(veg ? 'Veg' : 'Non-veg',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? color : null)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline)),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      );
}

const _prefLabels = <String, String>{
  'less_spicy': 'Less spicy',
  'normal_spicy': 'Normal spicy',
  'extra_spicy': 'Extra spicy',
  'no_onion': 'No onion',
  'no_garlic': 'No garlic',
  'less_oil': 'Less oil',
  'extra_rice': 'Extra rice',
};

// ── Edit catalog details (name, price, preferences, remove from catalog) ─────
class _EditDishDetailsScreen extends ConsumerStatefulWidget {
  const _EditDishDetailsScreen({required this.dateStr, required this.dish});
  final String dateStr;
  final DailyDish dish;

  @override
  ConsumerState<_EditDishDetailsScreen> createState() =>
      _EditDishDetailsScreenState();
}

class _EditDishDetailsScreenState
    extends ConsumerState<_EditDishDetailsScreen> {
  late final _name = TextEditingController(text: widget.dish.name);
  late final _price =
      TextEditingController(text: (widget.dish.pricePaise ~/ 100).toString());
  late bool _isVeg = widget.dish.isVeg;
  final _prefs = <String>{};
  final _picker = ImagePicker();
  XFile? _newPhoto;
  
  bool _saving = false;
  bool _deleting = false;
  bool _prefsLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    // Preferences live on the catalog item; pull the current set to pre-fill.
    try {
      final items = await ref.read(apiClientProvider).getList('/menu/items');
      final match = items
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == widget.dish.menuItemId,
              orElse: () => const {});
      final prefs = (match['preferences'] as List?) ?? const [];
      setState(() {
        _prefs.addAll(prefs.map((p) => (p as Map)['preference'] as String));
        _prefsLoaded = true;
      });
    } catch (_) {
      setState(() => _prefsLoaded = true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final rupees = int.tryParse(_price.text.trim());
    if (name.isEmpty) return setState(() => _error = 'Dish name is required');
    if (rupees == null || rupees <= 0) {
      return setState(() => _error = 'Enter a valid price');
    }
    if (rupees > 200) return setState(() => _error = 'Price cannot exceed ₹200');

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final id = widget.dish.menuItemId;
      String? updatedPhotoUrl;
      
      if (_newPhoto != null) {
        final res = await api.postMultipart('/menu/items/$id/photo',
            files: {'photo': [_newPhoto!.path]});
        updatedPhotoUrl = res['photoUrl'] as String?;
      }
      
      await api.patch('/menu/items/$id',
          body: {'name': name, 'pricePaise': rupees * 100, 'isVeg': _isVeg});
      await api.put('/menu/items/$id/preferences',
          body: {'preferences': _prefs.toList()});
          
      // Reflect the catalog edit locally without disturbing staged daily edits.
      ref.read(dailyMenuProvider(widget.dateStr).notifier).patchCatalog(
            id,
            name: name,
            pricePaise: rupees * 100,
            isVeg: _isVeg,
            photoUrl: updatedPhotoUrl,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove dish from catalog?'),
        content: Text(
            '"${widget.dish.name}" will be removed from your dishes entirely.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .delete('/menu/items/${widget.dish.menuItemId}');
      ref
          .read(dailyMenuProvider(widget.dateStr).notifier)
          .removeCatalogDish(widget.dish.menuItemId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to remove: $e';
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Dish')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) setState(() => _newPhoto = picked);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: HomelyColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HomelyColors.surfaceAlt),
                  ),
                  child: _newPhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_newPhoto!.path),
                              fit: BoxFit.cover))
                      : (widget.dish.photoUrl != null &&
                              widget.dish.photoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(widget.dish.photoUrl!,
                                  fit: BoxFit.cover))
                          : const Icon(Icons.add_a_photo,
                              color: HomelyColors.inkFaint)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Dish Name *'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Price (₹) *', prefixText: '₹ ', helperText: 'Max ₹200'),
          ),
          const SizedBox(height: 24),
          Text('Food type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _VegSelector(
            isVeg: _isVeg,
            onChanged: (v) => setState(() => _isVeg = v),
          ),
          const SizedBox(height: 24),
          Text('Preferences offered',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!_prefsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _prefLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _prefs.contains(entry.key),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _prefs.add(entry.key);
                      } else {
                        _prefs.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Changes'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove from catalog'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

// ── New catalog dish (name, price, photo). Returns {id,name,pricePaise,photoUrl}
class _NewDishScreen extends ConsumerStatefulWidget {
  const _NewDishScreen();

  @override
  ConsumerState<_NewDishScreen> createState() => _NewDishScreenState();
}

class _NewDishScreenState extends ConsumerState<_NewDishScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  bool _isVeg = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final rupees = int.tryParse(_price.text.trim());
    if (name.isEmpty) return setState(() => _error = 'Dish name is required');
    if (rupees == null || rupees <= 0) {
      return setState(() => _error = 'Enter a valid price');
    }
    if (rupees > 200) {
      return setState(() => _error = 'Price cannot exceed ₹200 per dish');
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final item = await api.post('/menu/items',
          body: {'name': name, 'pricePaise': rupees * 100, 'isVeg': _isVeg});
      final id = item['id'] as String;
      String? photoUrl;
      if (_photo != null) {
        final res = await api.postMultipart('/menu/items/$id/photo', files: {
          'photo': [_photo!.path],
        });
        photoUrl = res['photoUrl'] as String?;
      }
      if (mounted) {
        Navigator.of(context).pop(<String, dynamic>{
          'id': id,
          'name': name,
          'pricePaise': rupees * 100,
          'photoUrl': photoUrl,
          'isVeg': _isVeg,
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to add dish: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Dish')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: _photo == null
                  ? Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Icon(Icons.add_a_photo,
                          color: Colors.grey, size: 32),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_photo!.path),
                          width: 120, height: 120, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Dish photo (optional)')),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Dish Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (₹) *',
              prefixText: '₹ ',
              helperText: 'Max ₹200 per dish',
            ),
          ),
          const SizedBox(height: 20),
          Text('Food type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _VegSelector(
            isVeg: _isVeg,
            onChanged: (v) => setState(() => _isVeg = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Set today\'s plate count on the menu screen after adding.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Dish'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
