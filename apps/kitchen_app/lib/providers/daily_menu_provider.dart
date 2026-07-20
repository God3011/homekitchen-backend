import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'kitchen_provider.dart';

/// One row on the daily-menu screen: a catalog dish annotated with a date's
/// stock. `onMenu` is true when a MenuDailyAvailability row exists for the date.
class DailyDish {
  final String menuItemId;
  final String name;
  final int pricePaise;
  final String? photoUrl;
  final bool isVeg;
  final bool onMenu;
  final int platesTotal;
  final int platesRemaining;
  final bool isAvailable;

  const DailyDish({
    required this.menuItemId,
    required this.name,
    required this.pricePaise,
    this.photoUrl,
    this.isVeg = true,
    required this.onMenu,
    required this.platesTotal,
    required this.platesRemaining,
    required this.isAvailable,
  });

  /// Plates sold so far today (total minus remaining, never negative).
  int get platesSold =>
      (platesTotal - platesRemaining).clamp(0, platesTotal).toInt();

  factory DailyDish.fromJson(Map<String, dynamic> j) => DailyDish(
        menuItemId: j['menuItemId'] as String,
        name: j['name'] as String,
        pricePaise: j['pricePaise'] as int,
        photoUrl: j['photoUrl'] as String?,
        isVeg: j['isVeg'] as bool? ?? true,
        onMenu: j['onMenu'] as bool,
        platesTotal: j['platesTotal'] as int,
        platesRemaining: j['platesRemaining'] as int,
        isAvailable: j['isAvailable'] as bool,
      );

  DailyDish copyWith({
    bool? onMenu,
    int? platesTotal,
    int? platesRemaining,
    bool? isAvailable,
  }) =>
      DailyDish(
        menuItemId: menuItemId,
        name: name,
        pricePaise: pricePaise,
        photoUrl: photoUrl,
        isVeg: isVeg,
        onMenu: onMenu ?? this.onMenu,
        platesTotal: platesTotal ?? this.platesTotal,
        platesRemaining: platesRemaining ?? this.platesRemaining,
        isAvailable: isAvailable ?? this.isAvailable,
      );

  /// The staged fields that a Save would persist. Used to detect edits.
  bool sameStateAs(DailyDish o) =>
      onMenu == o.onMenu &&
      platesTotal == o.platesTotal &&
      isAvailable == o.isAvailable;
}

/// Immutable screen state: the server snapshot (`baseline`) plus the locally
/// staged edits (`working`). Nothing is persisted until [DailyMenuNotifier.save].
class DailyMenuState {
  final String date; // "YYYY-MM-DD" being viewed
  final bool loading;
  final String? error;
  final bool readOnly; // past date → view-only
  final bool saving;
  final List<DailyDish> baseline; // last-known server state
  final List<DailyDish> working; // staged edits

  const DailyMenuState({
    required this.date,
    this.loading = true,
    this.error,
    this.readOnly = false,
    this.saving = false,
    this.baseline = const [],
    this.working = const [],
  });

  DailyMenuState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    bool? readOnly,
    bool? saving,
    List<DailyDish>? baseline,
    List<DailyDish>? working,
  }) =>
      DailyMenuState(
        date: date,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        readOnly: readOnly ?? this.readOnly,
        saving: saving ?? this.saving,
        baseline: baseline ?? this.baseline,
        working: working ?? this.working,
      );

  /// True when any staged edit differs from the server baseline.
  bool get dirty {
    if (working.length != baseline.length) return true;
    final base = {for (final d in baseline) d.menuItemId: d};
    for (final d in working) {
      final b = base[d.menuItemId];
      if (b == null || !d.sameStateAs(b)) return true;
    }
    return false;
  }

  List<DailyDish> get onMenu =>
      working.where((d) => d.onMenu).toList(growable: false);
  List<DailyDish> get offMenu =>
      working.where((d) => !d.onMenu).toList(growable: false);

  bool get hasCatalog => working.isNotEmpty;
}

/// Loads a date's daily menu and holds staged edits until an explicit Save,
/// which writes ONE batch PUT (upserts + removals) and re-syncs to the result.
class DailyMenuNotifier extends StateNotifier<DailyMenuState> {
  DailyMenuNotifier(this._api, String date)
      : super(DailyMenuState(date: date)) {
    load();
  }

  final ApiClient _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data =
          await _api.get('/menu/daily', queryParams: {'date': state.date});
      final dishes = _parse(data);
      state = DailyMenuState(
        date: (data['serviceDate'] as String?) ?? state.date,
        loading: false,
        readOnly: (data['readOnly'] as bool?) ?? false,
        baseline: dishes,
        working: dishes,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  List<DailyDish> _parse(Map<String, dynamic> data) =>
      ((data['dishes'] as List?) ?? const [])
          .map((e) => DailyDish.fromJson(e as Map<String, dynamic>))
          .toList();

  void _mutate(String id, DailyDish Function(DailyDish) f) {
    state = state.copyWith(working: [
      for (final d in state.working) d.menuItemId == id ? f(d) : d,
    ]);
  }

  /// Set today's plate count for a dish (staged). Clamped at 0. Mirrors the
  /// backend's sold-preserving math so the "X left · Y sold" line stays correct
  /// live: remaining = max(0, newTotal - soldSoFar).
  void setPlates(String id, int total) {
    if (total < 0) total = 0;
    _mutate(id, (d) {
      final sold = (d.platesTotal - d.platesRemaining).clamp(0, d.platesTotal);
      final remaining = total - sold;
      return d.copyWith(
        platesTotal: total,
        platesRemaining: remaining < 0 ? 0 : remaining,
      );
    });
  }

  void incPlates(String id, [int by = 1]) {
    final d = state.working.firstWhere((x) => x.menuItemId == id);
    setPlates(id, d.platesTotal + by);
  }

  void decPlates(String id, [int by = 1]) {
    final d = state.working.firstWhere((x) => x.menuItemId == id);
    setPlates(id, d.platesTotal - by);
  }

  /// Sold-out toggle: false = stop selling even if plates remain.
  void setAvailable(String id, bool available) =>
      _mutate(id, (d) => d.copyWith(isAvailable: available));

  /// Quick-add a catalog dish to today with a default plate count (staged).
  /// A fresh add has no sales yet, so remaining = total.
  void quickAdd(String id, {int plates = 10}) => _mutate(
        id,
        (d) => d.copyWith(
          onMenu: true,
          platesTotal: plates,
          platesRemaining: plates,
          isAvailable: true,
        ),
      );

  /// Remove a dish from today's menu (staged; deletes its stock row on Save).
  void removeFromToday(String id) => _mutate(id, (d) => d.copyWith(onMenu: false));

  /// Fold a freshly-created catalog dish into the staged menu without a reload,
  /// so any other pending edits survive. Baseline keeps it off-menu (no server
  /// stock row yet); working stages it on-menu so Save upserts it.
  void addNewlyCreatedDish({
    required String menuItemId,
    required String name,
    required int pricePaise,
    String? photoUrl,
    bool isVeg = true,
    int plates = 10,
  }) {
    final base = DailyDish(
      menuItemId: menuItemId,
      name: name,
      pricePaise: pricePaise,
      photoUrl: photoUrl,
      isVeg: isVeg,
      onMenu: false,
      platesTotal: 0,
      platesRemaining: 0,
      isAvailable: false,
    );
    state = state.copyWith(
      baseline: [...state.baseline, base],
      working: [
        ...state.working,
        base.copyWith(
          onMenu: true,
          platesTotal: plates,
          platesRemaining: plates,
          isAvailable: true,
        ),
      ],
    );
  }

  /// Reflect a catalog edit (name/price/photo persisted immediately elsewhere)
  /// into both baseline and working without touching staged daily edits — these
  /// fields aren't part of `sameStateAs`, so `dirty` is unaffected.
  void patchCatalog(String id,
      {String? name, int? pricePaise, String? photoUrl, bool? isVeg}) {
    DailyDish upd(DailyDish d) => d.menuItemId != id
        ? d
        : DailyDish(
            menuItemId: d.menuItemId,
            name: name ?? d.name,
            pricePaise: pricePaise ?? d.pricePaise,
            photoUrl: photoUrl ?? d.photoUrl,
            isVeg: isVeg ?? d.isVeg,
            onMenu: d.onMenu,
            platesTotal: d.platesTotal,
            platesRemaining: d.platesRemaining,
            isAvailable: d.isAvailable,
          );
    state = state.copyWith(
      baseline: state.baseline.map(upd).toList(),
      working: state.working.map(upd).toList(),
    );
  }

  /// Drop a deactivated catalog dish (DELETE persisted elsewhere) from view.
  void removeCatalogDish(String id) => state = state.copyWith(
        baseline:
            state.baseline.where((d) => d.menuItemId != id).toList(),
        working: state.working.where((d) => d.menuItemId != id).toList(),
      );

  /// Throw away staged edits, reverting to the server baseline.
  void discard() => state = state.copyWith(working: state.baseline);

  /// Persist all staged edits in one batch PUT, then re-sync to the response.
  Future<void> save() async {
    final base = {for (final d in state.baseline) d.menuItemId: d};
    final upserts = <Map<String, dynamic>>[];
    final removals = <String>[];
    for (final d in state.working) {
      final b = base[d.menuItemId];
      if (d.onMenu) {
        if (b == null || !d.sameStateAs(b)) {
          upserts.add({
            'menuItemId': d.menuItemId,
            'platesTotal': d.platesTotal,
            'isAvailable': d.isAvailable,
          });
        }
      } else if (b != null && b.onMenu) {
        removals.add(d.menuItemId);
      }
    }

    state = state.copyWith(saving: true, clearError: true);
    try {
      final data = await _api.put('/menu/daily', body: {
        'date': state.date,
        'upserts': upserts,
        'removals': removals,
      }) as Map<String, dynamic>;
      final dishes = _parse(data);
      state = DailyMenuState(
        date: (data['serviceDate'] as String?) ?? state.date,
        loading: false,
        readOnly: (data['readOnly'] as bool?) ?? false,
        baseline: dishes,
        working: dishes,
      );
    } catch (e) {
      state = state.copyWith(saving: false, error: '$e');
      rethrow;
    }
  }
}

/// One notifier per viewed date. autoDispose so switching dates starts fresh.
final dailyMenuProvider = StateNotifierProvider.autoDispose
    .family<DailyMenuNotifier, DailyMenuState, String>((ref, date) {
  return DailyMenuNotifier(ref.watch(apiClientProvider), date);
});
