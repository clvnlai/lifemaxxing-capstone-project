import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/screens/health_widgets.dart';
import 'package:lifemaxxing/services/data_service.dart';

// Daily goals. Change these numbers to suit you.
const _sleepGoal = 8.0;
const _exerciseGoal = 30.0;
const _moodGoal = 4.0;

const _moodEmoji = ['😞', '😕', '😐', '🙂', '😄'];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
];
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
const _weekShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

typedef LogMap = Map<String, Map<String, dynamic>>;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double _n(dynamic v) => v is num ? v.toDouble() : 0.0;

String _f1(double v) => v.toStringAsFixed(1);

String _pct(double? v, double goal) =>
    v == null ? '–' : '${(v / goal * 100).clamp(0, 100).round()}%';

List<DateTime> _daysIn(DateTime a, DateTime b) {
  final n = b.difference(a).inDays;
  return List.generate(n + 1, (i) => DateTime(a.year, a.month, a.day + i));
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _service = DataService('healthLogs');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      _service.streamAll();

  int _period = 1; // 0 day, 1 week, 2 month
  DateTime _anchor = _day(DateTime.now());

  // ---------------------------------------------------------------------
  // Period handling
  // ---------------------------------------------------------------------

  (DateTime, DateTime) get _range {
    switch (_period) {
      case 0:
        return (_anchor, _anchor);
      case 1:
        final start = DateTime(
            _anchor.year, _anchor.month, _anchor.day - (_anchor.weekday - 1));
        return (start, DateTime(start.year, start.month, start.day + 6));
      default:
        return (
          DateTime(_anchor.year, _anchor.month, 1),
          DateTime(_anchor.year, _anchor.month + 1, 0)
        );
    }
  }

  bool get _canGoNext => _range.$2.isBefore(_day(DateTime.now()));

  void _shift(int dir) {
    setState(() {
      switch (_period) {
        case 0:
          _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + dir);
          break;
        case 1:
          _anchor =
              DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
          break;
        default:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
      }
    });
  }

  String _label() {
    final (s, e) = _range;
    final today = _day(DateTime.now());
    switch (_period) {
      case 0:
        final diff = _anchor.difference(today).inDays;
        if (diff == 0) return 'Today';
        if (diff == -1) return 'Yesterday';
        return '${_weekShort[_anchor.weekday - 1]}, ${_anchor.day} ${_monthShort[_anchor.month - 1]} ${_anchor.year}';
      case 1:
        return s.month == e.month
            ? '${s.day} – ${e.day} ${_monthShort[e.month - 1]} ${e.year}'
            : '${s.day} ${_monthShort[s.month - 1]} – ${e.day} ${_monthShort[e.month - 1]} ${e.year}';
      default:
        return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
    }
  }

  // ---------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------

  int _loggingStreak(LogMap byDay) {
    var d = _day(DateTime.now());
    if (!byDay.containsKey(_key(d))) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (byDay.containsKey(_key(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int _goalStreak(LogMap byDay, DateTime end, String field, double goal) {
    var d = end;
    if (_same(d, _day(DateTime.now())) && !byDay.containsKey(_key(d))) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    var n = 0;
    while (byDay.containsKey(_key(d)) && _n(byDay[_key(d)]![field]) >= goal) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hBg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: hExercise,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.white)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byDay = <String, Map<String, dynamic>>{
            for (final d in snap.data!.docs) d.id: d.data(),
          };
          return _content(context, byDay);
        },
      ),
    );
  }

  Widget _content(BuildContext context, LogMap byDay) {
    final (start, end) = _range;
    final rangeDays = _daysIn(start, end);
    final inRange = rangeDays.where((d) => byDay.containsKey(_key(d))).toList();

    // Days shown in the trend bars
    final chartDays = _period == 0
        ? List.generate(
            7, (i) => DateTime(end.year, end.month, end.day - 6 + i))
        : rangeDays;

    double? avgOf(String field) {
      if (inRange.isEmpty) return null;
      final v = inRange.map((d) => _n(byDay[_key(d)]![field])).toList();
      return v.reduce((a, b) => a + b) / v.length;
    }

    final sleep = avgOf('sleepHours');
    final exercise = avgOf('exerciseMinutes');
    final mood = avgOf('mood');

    var met = 0;
    for (final d in inRange) {
      final m = byDay[_key(d)]!;
      if (_n(m['sleepHours']) >= _sleepGoal) met++;
      if (_n(m['exerciseMinutes']) >= _exerciseGoal) met++;
      if (_n(m['mood']) >= _moodGoal) met++;
    }
    final total = inRange.length * 3;

    final streak = _loggingStreak(byDay);
    final prefix = _period == 0 ? '' : 'Avg ';

    // Chart helpers
    List<double?> series(String f) => [
          for (final d in chartDays)
            byDay[_key(d)] == null ? null : _n(byDay[_key(d)]![f]),
        ];
    double? avgSeries(List<double?> s) {
      final v = s.whereType<double>().toList();
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    double maxOf(List<double?> s, double goal) {
      var m = goal * 1.5;
      for (final v in s) {
        if (v != null && v > m) m = v;
      }
      return m;
    }

    final labels = [for (final d in chartDays) 'MTWTFSS'[d.weekday - 1]];
    final chartEnd = chartDays.last;
    final sleepS = series('sleepHours');
    final exS = series('exerciseMinutes');
    final moodS = series('mood');
    final sleepAvg = avgSeries(sleepS);
    final exAvg = avgSeries(exS);
    final moodAvg = avgSeries(moodS);

    final entryDays = inRange.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _segments(),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _shift(-1),
            ),
            Expanded(
              child: Center(
                child: Text(_label(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: _canGoNext ? Colors.white : hBorder),
              onPressed: _canGoNext ? () => _shift(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Goals card
        HCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Daily goals',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text(total == 0 ? 'No logs yet' : '$met / $total met',
                      style: const TextStyle(color: hMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              HProgressBar(
                  value: total == 0 ? 0 : met / total,
                  color: hExercise,
                  height: 12),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  HRing(
                    progress: sleep == null ? 0 : sleep / _sleepGoal,
                    color: hSleep,
                    icon: Icons.bedtime_outlined,
                    value: _pct(sleep, _sleepGoal),
                    label: 'Sleep',
                  ),
                  HRing(
                    progress: exercise == null ? 0 : exercise / _exerciseGoal,
                    color: hExercise,
                    icon: Icons.directions_run,
                    value: _pct(exercise, _exerciseGoal),
                    label: 'Exercise',
                  ),
                  HRing(
                    progress: mood == null ? 0 : mood / _moodGoal,
                    color: hMood,
                    icon: Icons.mood,
                    value: _pct(mood, _moodGoal),
                    label: 'Mood',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tiles
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HMetricTile(
                  icon: Icons.bedtime_outlined,
                  title: '${prefix}sleep',
                  value: sleep == null ? '–' : '${_f1(sleep)} h',
                  sub: sleep == null
                      ? 'No data'
                      : sleep >= _sleepGoal
                          ? 'Goal met'
                          : '${_f1(_sleepGoal - sleep)} h below goal',
                  progress: sleep == null ? 0 : sleep / _sleepGoal,
                  color: hSleep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HMetricTile(
                  icon: Icons.directions_run,
                  title: '${prefix}exercise',
                  value: exercise == null ? '–' : '${exercise.round()} min',
                  sub: exercise == null
                      ? 'No data'
                      : exercise >= _exerciseGoal
                          ? 'Goal met'
                          : '${(_exerciseGoal - exercise).round()} min to go',
                  progress: exercise == null ? 0 : exercise / _exerciseGoal,
                  color: hExercise,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HMetricTile(
                  icon: Icons.mood,
                  title: '${prefix}mood',
                  value: mood == null
                      ? '–'
                      : '${_moodEmoji[mood.round().clamp(1, 5) - 1]} ${_f1(mood)}',
                  sub: 'out of 5',
                  progress: mood == null ? 0 : mood / 5,
                  color: hMood,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HMetricTile(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Logging streak',
                  value: '$streak ${streak == 1 ? 'day' : 'days'}',
                  sub: 'logged in a row',
                  progress: streak / 7,
                  color: hStreak,
                ),
              ),
            ],
          ),
        ),

        // Trends
        const SizedBox(height: 20),
        const Text('Trends',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Bright bars reached your goal',
            style: TextStyle(color: hMuted, fontSize: 12)),
        const SizedBox(height: 10),
        HBarRow(
          icon: Icons.bedtime_outlined,
          title: 'Sleep',
          color: hSleep,
          goal: _sleepGoal,
          maxValue: maxOf(sleepS, _sleepGoal),
          values: sleepS,
          labels: labels,
          avg: sleepAvg == null ? 'No data' : '${_f1(sleepAvg)} h avg',
          streak:
              '${_goalStreak(byDay, chartEnd, 'sleepHours', _sleepGoal)} day streak',
        ),
        const SizedBox(height: 10),
        HBarRow(
          icon: Icons.directions_run,
          title: 'Exercise',
          color: hExercise,
          goal: _exerciseGoal,
          maxValue: maxOf(exS, _exerciseGoal),
          values: exS,
          labels: labels,
          avg: exAvg == null ? 'No data' : '${exAvg.round()} min avg',
          streak:
              '${_goalStreak(byDay, chartEnd, 'exerciseMinutes', _exerciseGoal)} day streak',
        ),
        const SizedBox(height: 10),
        HBarRow(
          icon: Icons.mood,
          title: 'Mood',
          color: hMood,
          goal: _moodGoal,
          maxValue: 5,
          values: moodS,
          labels: labels,
          avg: moodAvg == null ? 'No data' : '${_f1(moodAvg)} / 5 avg',
          streak:
              '${_goalStreak(byDay, chartEnd, 'mood', _moodGoal)} day streak',
        ),

        // Entries
        const SizedBox(height: 20),
        const Text('Entries',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (entryDays.isEmpty)
          const HCard(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 14),
            child: Center(
              child: Text('No entries in this period. Tap + to add one.',
                  style: TextStyle(color: hMuted)),
            ),
          )
        else
          for (final d in entryDays) _entryTile(context, d, byDay[_key(d)]!),
      ],
    );
  }

  Widget _segments() {
    const labels = ['Day', 'Week', 'Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hBorder),
      ),
      child: Row(
        children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _period = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _period == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _period == i ? hBg : hMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryTile(BuildContext context, DateTime d, Map<String, dynamic> m) {
    final mood = _n(m['mood']).round().clamp(1, 5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showForm(context, id: _key(d), existing: m),
        child: HCard(
          child: Row(
            children: [
              Text(_moodEmoji[mood - 1], style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weekShort[d.weekday - 1]}, ${d.day} ${_monthShort[d.month - 1]}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Sleep ${_f1(_n(m['sleepHours']))} h • Exercise ${_n(m['exerciseMinutes']).round()} min',
                      style: const TextStyle(color: hMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: hMuted),
                onPressed: () => _delete(context, _key(d), m),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _delete(BuildContext context, String id, Map<String, dynamic> raw) {
    _service.delete(id);
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _service.set(id, raw),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Add / edit sheet
  // ---------------------------------------------------------------------

  void _showForm(BuildContext context,
      {String? id, Map<String, dynamic>? existing}) {
        String fmt(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

    final sleepC = TextEditingController(
        text: existing == null ? '' : fmt((existing['sleepHours'] as num?) ?? 0));
    final exerciseC = TextEditingController(
        text: existing == null
            ? ''
            : fmt((existing['exerciseMinutes'] as num?) ?? 0));
    var mood = ((existing?['mood'] as num?) ?? 3).toInt().clamp(1, 5);
    var date = id != null
        ? DateTime.parse(id)
        : (_period == 0 ? _anchor : _day(DateTime.now()));
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
                Text(id == null ? 'New health log' : 'Edit health log',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(_key(date)),
                  onPressed: id != null
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheet(() => date = _day(picked));
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sleepC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Sleep (hours)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exerciseC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Exercise (minutes)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Mood'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (i) {
                    return ChoiceChip(
                      label: Text(_moodEmoji[i],
                          style: const TextStyle(fontSize: 22)),
                      selected: mood == i + 1,
                      onSelected: (_) => setSheet(() => mood = i + 1),
                    );
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final s = double.tryParse(sleepC.text.trim());
                    final e = int.tryParse(exerciseC.text.trim()) ?? 0;
                    if (s == null || s < 0 || s > 24) {
                      setSheet(
                          () => error = 'Enter sleep between 0 and 24 hours');
                      return;
                    }
                    if (e < 0 || e > 1440) {
                      setSheet(() => error = 'Enter valid exercise minutes');
                      return;
                    }
                    await _service.set(_key(date), {
                      'date': _key(date),
                      'sleepHours': s,
                      'exerciseMinutes': e,
                      'mood': mood,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) setState(() => _anchor = _day(date));
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