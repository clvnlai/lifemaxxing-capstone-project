import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

typedef DocList = List<Map<String, dynamic>>;
typedef Data = Map<String, DocList>;

const _bg = Color(0xFFF4F6F9);
const _border = Color(0xFFE6E9EF);
const _blue = Color(0xFF2F6BFF);
const _blueLight = Color(0xFFCFE0FB);
const _ink = Color(0xFF1A1D24);
const _muted = Color(0xFF6B7280);

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String _keyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
const _months = [
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

// ---------------------------------------------------------------------------
// Dashboard screen
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Container(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(
            uid: user.uid,
            fallback: user.displayName ?? user.email ?? 'there',
          ),
          const SizedBox(height: 16),
          _Live(
            collections: const [
              'tasks',
              'habits',
              'habitLogs',
              'healthLogs',
              'transactions',
            ],
            builder: (context, d) => Column(
              children: [
                _statsRow(d),
                const SizedBox(height: 12),
                _ActivityChart(data: d),
                const SizedBox(height: 12),
                _quickActions(),
                const SizedBox(height: 12),
                _progressCard(d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- stat cards ----------
  Widget _statsRow(Data d) {
    final tasks = d['tasks']!;
    final doneTasks = tasks.where((t) => t['done'] == true).length;

    final habits = d['habits']!;
    final logIds = d['habitLogs']!.map((l) => l['id'] as String).toSet();
    final today = _keyOf(DateTime.now());
    final habitsToday =
        habits.where((h) => logIds.contains('${h['id']}_$today')).length;

    final now = DateTime.now();
    double spent = 0;
    for (final t in d['transactions']!) {
      if (t['type'] == 'income') continue;
      final dt = (t['date'] as Timestamp?)?.toDate();
      if (dt != null && dt.year == now.year && dt.month == now.month) {
        spent += (t['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
              label: 'Tasks done',
              value: '$doneTasks',
              caption: 'of ${tasks.length}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              label: 'Habits today',
              value: '$habitsToday',
              caption: 'of ${habits.length}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              label: 'Spent',
              value: 'RM ${spent.toStringAsFixed(0)}',
              caption: 'this month'),
        ),
      ],
    );
  }

  // ---------- quick actions ----------
  Widget _quickActions() {
    const items = [
      _Action(Icons.checklist, 'Add a task', 'Plan your day', 1),
      _Action(Icons.repeat, 'Check off habits', 'Keep your streaks alive', 2),
      _Action(Icons.bedtime_outlined, 'Log sleep and mood', 'Takes 20 seconds', 2),
      _Action(Icons.payments_outlined, 'Add an expense', 'Track your spending', 3),
      _Action(Icons.auto_awesome, 'AI insights', 'Personal tips from your data', 4),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick actions',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 2),
          const Text('Log something today',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 8),
          for (final a in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(a.icon, size: 20, color: _ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _ink)),
                        Text(a.subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => onNavigate(a.tab),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      foregroundColor: _ink,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- progress ----------
  Widget _progressCard(Data d) {
    final tasks = d['tasks']!;
    final doneTasks = tasks.where((t) => t['done'] == true).length;

    final habits = d['habits']!;
    final logIds = d['habitLogs']!.map((l) => l['id'] as String).toSet();
    final today = _keyOf(DateTime.now());
    final habitsToday =
        habits.where((h) => logIds.contains('${h['id']}_$today')).length;

    final byDate = {for (final l in d['healthLogs']!) l['id'] as String: l};
    final base = _dayOf(DateTime.now());
    final sleeps = <double>[];
    for (var i = 0; i < 7; i++) {
      final k = _keyOf(base.subtract(Duration(days: i)));
      final s = (byDate[k]?['sleepHours'] as num?)?.toDouble();
      if (s != null) sleeps.add(s);
    }
    final avgSleep =
        sleeps.isEmpty ? 0.0 : sleeps.reduce((a, b) => a + b) / sleeps.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Tasks completed',
            trailing: '$doneTasks / ${tasks.length}',
            value: tasks.isEmpty ? 0 : doneTasks / tasks.length,
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Habits today',
            trailing: '$habitsToday / ${habits.length}',
            value: habits.isEmpty ? 0 : habitsToday / habits.length,
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Sleep vs 8 h goal (7-day avg)',
            trailing: '${avgSleep.toStringAsFixed(1)} / 8 h',
            value: avgSleep / 8,
          ),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String title;
  final String subtitle;
  final int tab;
  const _Action(this.icon, this.title, this.subtitle, this.tab);
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String uid;
  final String fallback;
  const _Header({required this.uid, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final name = (snap.data?.data()?['name'] as String?) ?? fallback;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $name',
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 2),
            Text(
              '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable pieces
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  const _StatCard(
      {required this.label, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: _ink)),
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String trailing;
  final double value;
  const _ProgressRow(
      {required this.label, required this.trailing, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: _ink)),
            ),
            Text(trailing,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: _blueLight,
            valueColor: const AlwaysStoppedAnimation(_blue),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly activity bar chart (no chart package needed)
// ---------------------------------------------------------------------------

class _ActivityChart extends StatefulWidget {
  final Data data;
  const _ActivityChart({required this.data});

  @override
  State<_ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<_ActivityChart> {
  int _metric = 0; // 0 sleep, 1 exercise, 2 spending
  int _selected = 6; // today

  static const _labels = ['Sleep', 'Exercise', 'Spending'];
  static const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<double> _values(List<DateTime> days) {
    final health = {
      for (final l in widget.data['healthLogs']!) l['id'] as String: l
    };
    return days.map((day) {
      final k = _keyOf(day);
      switch (_metric) {
        case 0:
          return (health[k]?['sleepHours'] as num?)?.toDouble() ?? 0.0;
        case 1:
          return (health[k]?['exerciseMinutes'] as num?)?.toDouble() ?? 0.0;
        default:
          double sum = 0;
          for (final t in widget.data['transactions']!) {
            if (t['type'] == 'income') continue;
            final dt = (t['date'] as Timestamp?)?.toDate();
            if (dt != null && _keyOf(dt) == k) {
              sum += (t['amount'] as num?)?.toDouble() ?? 0;
            }
          }
          return sum;
      }
    }).toList();
  }

  String _fmt(double v) {
    switch (_metric) {
      case 0:
        return '${v.toStringAsFixed(1)} h';
      case 1:
        return '${v.toStringAsFixed(0)} min';
      default:
        return 'RM ${v.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _dayOf(DateTime.now());
    final days =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final values = _values(days);
    var maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    if (maxV == 0) maxV = 1;
    const maxBar = 120.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 days',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 2),
          const Text('Tap a bar for details',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _labels.length; i++)
                ChoiceChip(
                  label: Text(_labels[i]),
                  selected: _metric == i,
                  showCheckmark: false,
                  selectedColor: _blueLight,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _border),
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: _metric == i ? _blue : _muted,
                      fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _metric = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (i == _selected)
                            SizedBox(
                              height: 26,
                              child: OverflowBox(
                                minWidth: 0,
                                maxWidth: 100,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _ink,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_fmt(values[i]),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: values[i] / maxV * maxBar < 6
                                ? 6
                                : values[i] / maxV * maxBar,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: i == _selected ? _blue : _blueLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _short[days[i].weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              color: i == _selected ? _ink : _muted,
                              fontWeight: i == _selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live data helper: listens to several collections and hands one Data map
// to the builder.
// ---------------------------------------------------------------------------

class _Live extends StatefulWidget {
  final List<String> collections;
  final Widget Function(BuildContext, Data) builder;
  const _Live({required this.collections, required this.builder});

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  late final List<Stream<QuerySnapshot<Map<String, dynamic>>>> _streams;

  @override
  void initState() {
    super.initState();
    _streams =
        widget.collections.map((c) => DataService(c).streamAll()).toList();
  }

  Widget _nest(int i, Data acc) {
    if (i == _streams.length) return widget.builder(context, acc);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streams[i],
      builder: (context, snap) {
        if (snap.hasError) return Text('Error: ${snap.error}');
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs =
            snap.data!.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        return _nest(i + 1, {...acc, widget.collections[i]: docs});
      },
    );
  }

  @override
  Widget build(BuildContext context) => _nest(0, {});
}