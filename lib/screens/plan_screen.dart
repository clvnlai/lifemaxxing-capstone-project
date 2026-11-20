import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

const _bg = Color(0xFFF4F6F9);
const _border = Color(0xFFE6E9EF);
const _blue = Color(0xFF2F6BFF);
const _purple = Color(0xFF7C5CFC);
const _red = Color(0xFFE5484D);
const _ink = Color(0xFF1A1D24);
const _muted = Color(0xFF6B7280);
const _doneGrey = Color(0xFFC5CAD3);

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

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// One row in the planner: either a task or an assignment.
class _Item {
  final String id;
  final bool isTask;
  final String title;
  final String subject;
  final DateTime? due;
  final bool done;
  final Map<String, dynamic> raw;

  _Item({
    required this.id,
    required this.isTask,
    required this.title,
    required this.subject,
    required this.due,
    required this.done,
    required this.raw,
  });

  String get collection => isTask ? 'tasks' : 'assignments';

  factory _Item.from(
      QueryDocumentSnapshot<Map<String, dynamic>> d, bool isTask) {
    final m = d.data();
    final ts = m['dueDate'];
    return _Item(
      id: d.id,
      isTask: isTask,
      title: (m['title'] ?? '') as String,
      subject: (m['subject'] ?? '') as String,
      due: ts is Timestamp ? _dayOf(ts.toDate()) : null,
      done: m['done'] == true,
      raw: m,
    );
  }
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _tasksStream = DataService('tasks').streamAll();
  final _assignStream = DataService('assignments').streamAll();

  late DateTime _selected = _dayOf(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month, 1);
  int _filter = 0; // 0 all, 1 tasks, 2 assignments

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tasksStream,
        builder: (context, t) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignStream,
          builder: (context, a) {
            if (t.hasError || a.hasError) {
              return Center(child: Text('Error: ${t.error ?? a.error}'));
            }
            if (!t.hasData || !a.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = [
              ...t.data!.docs.map((d) => _Item.from(d, true)),
              ...a.data!.docs.map((d) => _Item.from(d, false)),
            ];
            final items = all
                .where((i) =>
                    _filter == 0 || (_filter == 1 ? i.isTask : !i.isTask))
                .toList();
            return _content(context, items);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Main content
  // ---------------------------------------------------------------------

  Widget _content(BuildContext context, List<_Item> items) {
    final today = _dayOf(DateTime.now());
    final isToday = _same(_selected, today);

    int order(_Item a, _Item b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }

    final onDay = items
        .where((i) => i.due != null && _same(i.due!, _selected))
        .toList()
      ..sort(order);
    final overdue = isToday
        ? (items
            .where((i) => !i.done && i.due != null && i.due!.isBefore(today))
            .toList()
          ..sort(order))
        : <_Item>[];
    final undated = isToday
        ? (items.where((i) => i.due == null).toList()..sort(order))
        : <_Item>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _calendar(items, today),
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _dayLabel(_selected, today),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _ink),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Text(
                '${onDay.length} ${onDay.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (onDay.isEmpty)
          _emptyCard()
        else
          for (final i in onDay) _tile(context, i, today),
        if (overdue.isNotEmpty) ...[
          _sectionLabel('Overdue'),
          for (final i in overdue) _tile(context, i, today),
        ],
        if (undated.isNotEmpty) ...[
          _sectionLabel('No due date'),
          for (final i in undated) _tile(context, i, today),
        ],
      ],
    );
  }

  String _dayLabel(DateTime d, DateTime today) {
    final diff = _dayOf(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${_weekShort[d.weekday - 1]}, ${d.day} ${_monthShort[d.month - 1]}';
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
      );

  Widget _emptyCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available, size: 32, color: _doneGrey),
            SizedBox(height: 8),
            Text('Nothing planned for this day',
                style: TextStyle(color: _muted)),
            SizedBox(height: 2),
            Text('Tap + to add something',
                style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      );

  // ---------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------

  Widget _filters() {
    const labels = ['All', 'Tasks', 'Assignments'];
    return Wrap(
      spacing: 8,
      children: [
        for (final (i, label) in labels.indexed)
          ChoiceChip(
            label: Text(label),
            selected: _filter == i,
            showCheckmark: false,
            selectedColor: const Color(0xFFCFE0FB),
            backgroundColor: Colors.white,
            side: const BorderSide(color: _border),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _filter == i ? _blue : _muted,
            ),
            onSelected: (_) => setState(() => _filter = i),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------

  void _goMonth(int delta) {
    final m = DateTime(_month.year, _month.month + delta, 1);
    final today = _dayOf(DateTime.now());
    setState(() {
      _month = m;
      _selected = (m.year == today.year && m.month == today.month) ? today : m;
    });
  }

  void _goToday() {
    final today = _dayOf(DateTime.now());
    setState(() {
      _selected = today;
      _month = DateTime(today.year, today.month, 1);
    });
  }

  Color _dotColor(_Item i, DateTime today) {
    if (i.done) return _doneGrey;
    if (i.due != null && i.due!.isBefore(today)) return _red;
    return i.isTask ? _blue : _purple;
  }

  Widget _calendar(List<_Item> items, DateTime today) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final rows = ((lead + daysIn) / 7).ceil();

    final byDay = <int, List<_Item>>{};
    for (final i in items) {
      final d = i.due;
      if (d != null && d.year == _month.year && d.month == _month.month) {
        byDay.putIfAbsent(d.day, () => []).add(i);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              TextButton(onPressed: _goToday, child: const Text('Today')),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _goMonth(-1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _goMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _dayCell(r * 7 + c - lead + 1, daysIn, today, byDay),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _blue, label: 'Task'),
              SizedBox(width: 14),
              _LegendDot(color: _purple, label: 'Assignment'),
              SizedBox(width: 14),
              _LegendDot(color: _red, label: 'Overdue'),
            ],
          ),
        ],
      ),
    );
  }

    Widget _dayCell(
      int day, int daysIn, DateTime today, Map<int, List<_Item>> byDay) {
    if (day < 1 || day > daysIn) return const SizedBox(height: 46);
    final date = DateTime(_month.year, _month.month, day);
    final selected = _same(date, _selected);
    final isToday = _same(date, today);
    final dots = (byDay[day] ?? []).take(3).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = date),
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _ink : null,
                border: !selected && isToday
                    ? Border.all(color: _blue, width: 1.5)
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected || isToday ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : _ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final i in dots)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dotColor(i, today),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // List tile
  // ---------------------------------------------------------------------

  Widget _tile(BuildContext context, _Item i, DateTime today) {
    final overdue = !i.done && i.due != null && i.due!.isBefore(today);
    final pillColor = overdue ? _red : (i.isTask ? _ink : _purple);
    final pillText = overdue ? 'Overdue' : (i.isTask ? 'Task' : 'Assignment');

    final sub = <String>[
      if (!i.isTask && i.subject.isNotEmpty) i.subject,
      if (overdue && i.due != null)
        'Due ${i.due!.day} ${_monthShort[i.due!.month - 1]}',
    ].join(' • ');

    return Dismissible(
      key: ValueKey('${i.collection}_${i.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _delete(context, i),
      child: GestureDetector(
        onTap: () => _showForm(context, edit: i),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    DataService(i.collection).update(i.id, {'done': !i.done}),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i.done ? _blue : Colors.transparent,
                    border: Border.all(
                        color: i.done ? _blue : _doneGrey, width: 1.8),
                  ),
                  child: i.done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: i.done ? _muted : _ink,
                        decoration:
                            i.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style:
                              const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pillText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _delete(BuildContext context, _Item i) {
    final svc = DataService(i.collection);
    svc.delete(i.id);
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        content: Text('Deleted "${i.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => svc.set(i.id, i.raw),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Add / edit sheet
  // ---------------------------------------------------------------------

  void _showForm(BuildContext context, {_Item? edit}) {
    final title = TextEditingController(text: edit?.title ?? '');
    final subject = TextEditingController(text: edit?.subject ?? '');
    var isTask = edit?.isTask ?? true;
    DateTime? due = edit != null ? edit.due : _selected;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(edit == null ? 'Add to your plan' : 'Edit item',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Task'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Assignment'),
                      icon: Icon(Icons.school_outlined),
                    ),
                  ],
                  selected: {isTask},
                  onSelectionChanged: edit == null
                      ? (Set<bool> s) => setSheet(() => isTask = s.first)
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  autofocus: edit == null,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                if (!isTask) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    decoration: const InputDecoration(
                        labelText: 'Subject (e.g. CS201)',
                        border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(due == null ? 'No due date' : _fmt(due!)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: due ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (p != null) setSheet(() => due = _dayOf(p));
                        },
                      ),
                    ),
                    if (due != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear date',
                        onPressed: () => setSheet(() => due = null),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style:
                          TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) {
                      setSheet(() => error = 'Enter a title');
                      return;
                    }
                    final data = <String, dynamic>{
                      'title': title.text.trim(),
                      if (!isTask) 'subject': subject.text.trim(),
                      'dueDate':
                          due == null ? null : Timestamp.fromDate(due!),
                    };
                    final svc =
                        DataService(isTask ? 'tasks' : 'assignments');
                    if (edit == null) {
                      await svc.add({...data, 'done': false});
                    } else {
                      await svc.update(edit.id, data);
                    }

                    // Jump the calendar to the saved date so it is visible
                    final d = due;
                    if (mounted) {
                      setState(() {
                        if (d != null) {
                          _selected = d;
                          _month = DateTime(d.year, d.month, 1);
                        }
                        if (_filter != 0 && ((_filter == 1) != isTask)) {
                          _filter = 0;
                        }
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(edit == null ? 'Save' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    );
  }
}