import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifemaxxing/services/data_service.dart';

enum DemoScenario { lowSleepOverspending, balanced }

class DemoData {
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static final _tasks = DataService('tasks');
  static final _assignments = DataService('assignments');
  static final _habits = DataService('habits');
  static final _logs = DataService('habitLogs');
  static final _health = DataService('healthLogs');
  static final _tx = DataService('transactions');

  static const _habitIds = ['demo_water', 'demo_read'];

  static Future<void> load(DemoScenario s) async {
    final bad = s == DemoScenario.lowSleepOverspending;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = Timestamp.now();

    // Index 0 = 6 days ago ... index 6 = today
    final sleep = bad
        ? [5.0, 7.5, 4.5, 7.0, 5.5, 4.0, 7.5]
        : [7.5, 8.0, 7.0, 7.5, 8.0, 7.0, 7.5];
    final exercise =
        bad ? [0, 30, 0, 20, 0, 0, 30] : [30, 45, 30, 40, 30, 45, 30];
    final mood = bad ? [2, 4, 2, 4, 3, 1, 4] : [4, 5, 4, 4, 5, 4, 5];
    final spend = bad
        ? [48.0, 12.0, 65.0, 15.0, 55.0, 70.0, 10.0]
        : [15.0, 18.0, 12.0, 20.0, 16.0, 22.0, 14.0];
    final habitsDone = bad ? [0, 2, 0, 1, 0, 0, 2] : [2, 2, 2, 1, 2, 2, 2];

    await _habits.set('demo_water', {'name': 'Drink 2L water', 'createdAt': created});
    await _habits.set('demo_read', {'name': 'Read 20 minutes', 'createdAt': created});

    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      final k = _key(day);

      await _health.set(k, {
        'date': k,
        'sleepHours': sleep[i],
        'exerciseMinutes': exercise[i],
        'mood': mood[i],
        'createdAt': created,
      });

      await _tx.set('demo_food_$k', {
        'type': 'expense',
        'amount': spend[i],
        'category': 'Food',
        'note': 'Sample',
        'date': Timestamp.fromDate(day.add(const Duration(hours: 12))),
        'createdAt': created,
      });

      for (var j = 0; j < _habitIds.length; j++) {
        final id = '${_habitIds[j]}_$k';
        if (habitsDone[i] > j) {
          await _logs.set(id, {
            'habitId': _habitIds[j],
            'date': k,
            'createdAt': created,
          });
        } else {
          await _logs.delete(id);
        }
      }
    }

    await _tx.set('demo_income', {
      'type': 'income',
      'amount': 500.0,
      'category': 'Allowance',
      'note': 'Sample',
      'date': Timestamp.fromDate(
          today.subtract(const Duration(days: 6)).add(const Duration(hours: 9))),
      'createdAt': created,
    });

    final taskDefs = bad
        ? [
            ('Finish lab report', -2, false),
            ('Reply to emails', -1, false),
            ('Gym session', 0, false),
            ('Plan next week', 2, false),
            ('Buy groceries', -3, true),
          ]
        : [
            ('Finish lab report', 1, true),
            ('Reply to emails', 0, true),
            ('Gym session', 0, true),
            ('Plan next week', 2, false),
            ('Buy groceries', -1, true),
          ];
    for (var i = 0; i < taskDefs.length; i++) {
      final (title, off, done) = taskDefs[i];
      await _tasks.set('demo_task_$i', {
        'title': title,
        'done': done,
        'dueDate': Timestamp.fromDate(today.add(Duration(days: off))),
        'createdAt': created,
      });
    }

    final assignDefs = bad
        ? [
            ('Data structures assignment', 'CS201', -1, false),
            ('Database report', 'CS305', 3, false),
          ]
        : [
            ('Data structures assignment', 'CS201', -1, true),
            ('Database report', 'CS305', 5, false),
          ];
    for (var i = 0; i < assignDefs.length; i++) {
      final (title, subject, off, done) = assignDefs[i];
      await _assignments.set('demo_assignment_$i', {
        'title': title,
        'subject': subject,
        'done': done,
        'dueDate': Timestamp.fromDate(today.add(Duration(days: off))),
        'createdAt': created,
      });
    }
  }

  static Future<void> clear() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 5; i++) {
      await _tasks.delete('demo_task_$i');
    }
    for (var i = 0; i < 2; i++) {
      await _assignments.delete('demo_assignment_$i');
    }
    for (final h in _habitIds) {
      await _habits.delete(h);
    }
    await _tx.delete('demo_income');
    for (var i = 0; i < 7; i++) {
      final k = _key(today.subtract(Duration(days: 6 - i)));
      await _health.delete(k);
      await _tx.delete('demo_food_$k');
      for (final h in _habitIds) {
        await _logs.delete('${h}_$k');
      }
    }
  }
}