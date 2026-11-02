import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

class HabitsScreen extends StatelessWidget {
  HabitsScreen({super.key});

  final _habits = DataService('habits');
  final _logs = DataService('habitLogs');

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _streak(Set<String> logIds, String habitId) {
    var day = DateTime.now();
    if (!logIds.contains('${habitId}_${_key(day)}')) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (logIds.contains('${habitId}_${_key(day)}')) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final today = _key(DateTime.now());
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addHabit(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _habits.stream(),
        builder: (context, habitSnap) {
          if (habitSnap.hasError) {
            return Center(child: Text('Error: ${habitSnap.error}'));
          }
          if (!habitSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final habits = habitSnap.data!.docs;
          if (habits.isEmpty) {
            return const Center(child: Text('No habits yet. Tap + to add one.'));
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _logs.streamAll(),
            builder: (context, logSnap) {
              final logIds = logSnap.hasData
                  ? logSnap.data!.docs.map((d) => d.id).toSet()
                  : <String>{};
              return ListView.builder(
                itemCount: habits.length,
                itemBuilder: (context, i) {
                  final habit = habits[i];
                  final name = (habit.data()['name'] ?? '') as String;
                  final doneToday = logIds.contains('${habit.id}_$today');
                  final streak = _streak(logIds, habit.id);
                  return ListTile(
                    leading: Checkbox(
                      value: doneToday,
                      onChanged: (v) {
                        final logId = '${habit.id}_$today';
                        if (v == true) {
                          _logs.set(logId, {
                            'habitId': habit.id,
                            'date': today,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          _logs.delete(logId);
                        }
                      },
                    ),
                    title: Text(name),
                    subtitle: Text(streak == 1
                        ? '1 day streak'
                        : '$streak day streak'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _habits.delete(habit.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _addHabit(BuildContext context) {
    final name = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New habit', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Habit name (e.g. Drink 2L water)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await _habits.add({'name': name.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}