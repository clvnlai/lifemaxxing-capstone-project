import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifemaxxing/screens/health_widgets.dart';
import 'package:lifemaxxing/services/data_service.dart';

const _sage = hNavy;
const _peach = hMood;

const _title = TextStyle(color: hInk, fontSize: 16, fontWeight: FontWeight.w700);
const _sub = TextStyle(color: hMuted, fontSize: 12);

const _suggestions = [
  'Drink 2L water',
  'Read 20 pages',
  'Stretch 10 min',
  'Morning walk',
  'Sugar-free day',
  'Sleep before 11pm',
];
const _weekShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _streak(String habitId, Set<String> logIds, DateTime today) {
  var d = today;
  if (!logIds.contains('${habitId}_${_key(d)}')) {
    d = DateTime(d.year, d.month, d.day - 1);
  }
  var n = 0;
  while (logIds.contains('${habitId}_${_key(d)}')) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

class _Habit {
  final String id;
  final String name;
  final DateTime? created;
  final Map<String, dynamic> raw;

  _Habit({
    required this.id,
    required this.name,
    required this.created,
    required this.raw,
  });

  factory _Habit.from(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final ts = m['createdAt'];
    return _Habit(
      id: d.id,
      name: (m['name'] ?? '') as String,
      created: ts is Timestamp ? _day(ts.toDate()) : null,
      raw: m,
    );
  }
}

/// 30-day completion rate, counted from the habit's first day.
double _rate(_Habit h, Set<String> logIds, DateTime today) {
  var first = h.created ?? today;
  final prefix = '${h.id}_';
  for (final id in logIds) {
    if (id.startsWith(prefix)) {
      final d = DateTime.tryParse(id.substring(prefix.length));
      if (d != null && d.isBefore(first)) first = d;
    }
  }
  var span = today.difference(_day(first)).inDays + 1;
  if (span > 30) span = 30;
  if (span < 1) span = 1;
  var n = 0;
  for (var i = 0; i < span; i++) {
    final d = DateTime(today.year, today.month, today.day - i);
    if (logIds.contains('${h.id}_${_key(d)}')) n++;
  }
  return n / span;
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _habitsSvc = DataService('habits');
  final _logsSvc = DataService('habitLogs');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _habitStream =
      _habitsSvc.streamAll();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _logStream =
      _logsSvc.streamAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hBg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: hInk,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _habitStream,
        builder: (context, hs) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _logStream,
          builder: (context, ls) {
            if (hs.hasError || ls.hasError) {
              return Center(child: Text('Error: ${hs.error ?? ls.error}'));
            }
            if (!hs.hasData || !ls.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final today = _day(DateTime.now());
            final habits = hs.data!.docs.map(_Habit.from).toList()
              ..sort((a, b) {
                final c = (a.created ?? today).compareTo(b.created ?? today);
                return c != 0
                    ? c
                    : a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
            final logIds = ls.data!.docs.map((d) => d.id).toSet();
            return _content(context, habits, logIds, today);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<_Habit> habits,
      Set<String> logIds, DateTime today) {
    final days = List.generate(
        7, (i) => DateTime(today.year, today.month, today.day - 6 + i));
    final todayKey = _key(today);
    final doneToday =
        habits.where((h) => logIds.contains('${h.id}_$todayKey')).length;
    var best = 0;
    for (final h in habits) {
      final s = _streak(h.id, logIds, today);
      if (s > best) best = s;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _todayCard(doneToday, habits.length, best, today),
        const SizedBox(height: 12),
        _checklistCard(context, habits, logIds, today, doneToday),
        if (habits.isNotEmpty) ...[
          const SizedBox(height: 12),
          _weekCard(habits, logIds, days, today),
          const SizedBox(height: 12),
          _consistencyCard(habits, logIds, days, today),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Top card
  // ---------------------------------------------------------------------

  Widget _todayCard(int done, int total, int best, DateTime today) {
    final headline = total == 0
        ? 'Start your first habit'
        : done == total
            ? 'All done today!'
            : '${total - done} to go today';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3E7EF), Color(0xFFF8F9FB)],        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: hBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withAlpha(150),
                    valueColor: const AlwaysStoppedAnimation(_sage),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$done/$total',
                        style: const TextStyle(
                            color: hInk,
                            fontSize: 26,
                            fontWeight: FontWeight.w700)),
                    const Text('done today', style: _sub),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: const TextStyle(
                        color: hInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${_weekShort[today.weekday - 1]}, ${today.day} ${_monthShort[today.month - 1]}',
                  style: _sub,
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(170),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 16, color: _peach),
                      const SizedBox(width: 4),
                      Text(
                        'Best streak: $best ${best == 1 ? 'day' : 'days'}',
                        style: const TextStyle(
                            color: hInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Today's checklist
  // ---------------------------------------------------------------------

  Widget _checklistCard(BuildContext context, List<_Habit> habits,
      Set<String> logIds, DateTime today, int doneToday) {
    return HCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Today’s habits', style: _title)),
              if (habits.isNotEmpty)
                Text('$doneToday of ${habits.length}', style: _sub),
            ],
          ),
          const SizedBox(height: 6),
          if (habits.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
                'No habits yet. Pick one to start, or tap + to create your own.',
                style: _sub),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in _suggestions.take(4))
                  ActionChip(
                    label: Text(s),
                    backgroundColor: hBg,
                    side: const BorderSide(color: hBorder),
                    onPressed: () => _habitsSvc.add({'name': s}),
                  ),
              ],
            ),
          ] else
            for (final h in habits)
              _habitRow(
                context,
                h,
                logIds.contains('${h.id}_${_key(today)}'),
                _streak(h.id, logIds, today),
                today,
              ),
        ],
      ),
    );
  }

  void _toggle(_Habit h, bool isDone, DateTime day) {
    HapticFeedback.selectionClick();
    final id = '${h.id}_${_key(day)}';
    if (isDone) {
      _logsSvc.delete(id);
    } else {
      _logsSvc.set(id, {
        'habitId': h.id,
        'date': _key(day),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Widget _habitRow(BuildContext context, _Habit h, bool isDone, int streak,
      DateTime today) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggle(h, isDone, today),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _sage : Colors.transparent,
                border: Border.all(
                    color: isDone ? _sage : const Color(0xFFC9C7BA),
                    width: 1.8),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggle(h, isDone, today),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    style: TextStyle(
                      color: isDone ? hMuted : hInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 14, color: streak > 0 ? _peach : hBorder),
                      const SizedBox(width: 3),
                      Text(
                        streak == 1 ? '1 day streak' : '$streak day streak',
                        style: _sub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: hMuted),
            onSelected: (v) {
              if (v == 'rename') {
                _showForm(context, edit: h);
              } else {
                _delete(context, h);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Last 7 days (capsules)
  // ---------------------------------------------------------------------

  Widget _weekCard(List<_Habit> habits, Set<String> logIds,
      List<DateTime> days, DateTime today) {
    final total = habits.length;
    final counts = [
      for (final d in days)
        habits.where((h) => logIds.contains('${h.id}_${_key(d)}')).length,
    ];
    final perfect = total == 0 ? 0 : counts.where((c) => c == total).length;

    return HCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Last 7 days', style: _title)),
              Text('$perfect perfect ${perfect == 1 ? 'day' : 'days'}',
                  style: _sub),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: Row(
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _capsule(
                      total == 0 ? 0.0 : counts[i] / total,
                      'MTWTFSS'[days[i].weekday - 1],
                      '${counts[i]}/$total',
                      i == days.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capsule(double f, String letter, String count, bool isToday) {
    final color = f >= 0.8 ? _sage : _peach;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Container(
              width: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: hBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hBorder, width: 1.5),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: f <= 0
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        widthFactor: 1.0,
                        heightFactor: f.clamp(0.1, 1.0).toDouble(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          letter,
          style: TextStyle(
            color: isToday ? hInk : hMuted,
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(count, style: const TextStyle(color: hMuted, fontSize: 10)),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Consistency
  // ---------------------------------------------------------------------

  Widget _consistencyCard(List<_Habit> habits, Set<String> logIds,
      List<DateTime> days, DateTime today) {
    return HCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Consistency', style: _title),
          const SizedBox(height: 2),
          const Text('Last 7 days and 30-day rate', style: _sub),
          const SizedBox(height: 10),
          for (final h in habits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: hInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final d in days)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: logIds.contains('${h.id}_${_key(d)}')
                            ? _sage
                            : hBorder,
                      ),
                    ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${(_rate(h, logIds, today) * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: hInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Delete and add / rename
  // ---------------------------------------------------------------------

  void _delete(BuildContext context, _Habit h) {
    _habitsSvc.delete(h.id);
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: Text('Deleted "${h.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _habitsSvc.set(h.id, h.raw),
        ),
      ),
    );
  }

  void _showForm(BuildContext context, {_Habit? edit}) {
    final c = TextEditingController(text: edit?.name ?? '');
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(edit == null ? 'New habit' : 'Rename habit',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Habit name', border: OutlineInputBorder()),
                ),
                if (edit == null) ...[
                  const SizedBox(height: 14),
                  const Text('Quick picks', style: _sub),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: () => setSheet(() {
                            c.text = s;
                            c.selection =
                                TextSelection.collapsed(offset: s.length);
                          }),
                        ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: hInk,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = c.text.trim();
                    if (name.isEmpty) {
                      setSheet(() => error = 'Enter a habit name');
                      return;
                    }
                    if (edit == null) {
                      await _habitsSvc.add({'name': name});
                    } else {
                      await _habitsSvc.update(edit.id, {'name': name});
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}