import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/kitchen_provider.dart';

const _dayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class _DayHours {
  bool enabled = false;
  TimeOfDay open = const TimeOfDay(hour: 11, minute: 0);
  TimeOfDay close = const TimeOfDay(hour: 15, minute: 0);
}

/// Editor for per-day open/close times (PUT /kitchens/me/hours).
class OperatingHoursScreen extends ConsumerStatefulWidget {
  const OperatingHoursScreen({super.key});

  @override
  ConsumerState<OperatingHoursScreen> createState() =>
      _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends ConsumerState<OperatingHoursScreen> {
  final List<_DayHours> _days = List.generate(7, (_) => _DayHours());
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).getList('/kitchens/me/hours');
      for (final e in data) {
        final m = e as Map<String, dynamic>;
        final dow = m['dayOfWeek'] as int;
        if (dow >= 0 && dow < 7) {
          _days[dow]
            ..enabled = true
            ..open = _parse(m['openTime'] as String)
            ..close = _parse(m['closeTime'] as String);
        }
      }
    } catch (_) {
      /* no hours set yet — leave defaults */
    }
    if (mounted) setState(() => _loading = false);
  }

  TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int day, bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _days[day].open : _days[day].close,
    );
    if (picked == null) return;
    setState(() {
      if (isOpen) {
        _days[day].open = picked;
      } else {
        _days[day].close = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final hours = [
      for (var i = 0; i < 7; i++)
        if (_days[i].enabled)
          {
            'dayOfWeek': i,
            'openTime': _fmt(_days[i].open),
            'closeTime': _fmt(_days[i].close),
          },
    ];
    try {
      await ref
          .read(apiClientProvider)
          .put('/kitchens/me/hours', body: {'hours': hours});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Hours saved')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operating Hours')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < 7; i++) _dayRow(i),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Hours'),
                ),
              ],
            ),
    );
  }

  Widget _dayRow(int i) {
    final d = _days[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 78, child: Text(_dayNames[i])),
            Switch(
              value: d.enabled,
              onChanged: (v) => setState(() => d.enabled = v),
            ),
            if (d.enabled) ...[
              Expanded(
                child: TextButton(
                  onPressed: () => _pickTime(i, true),
                  child: Text(_fmt(d.open)),
                ),
              ),
              const Text('–'),
              Expanded(
                child: TextButton(
                  onPressed: () => _pickTime(i, false),
                  child: Text(_fmt(d.close)),
                ),
              ),
            ] else
              const Expanded(
                  child: Text('Closed', textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
