import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

class HealthScreen extends StatelessWidget {
  HealthScreen({super.key});

  final _service = DataService('healthLogs');

  static const _moods = ['😞', '😕', '😐', '🙂', '😄'];

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _num(num n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.toList()
            ..sort((a, b) => b.id.compareTo(a.id)); // newest date first
          if (docs.isEmpty) {
            return const Center(
                child: Text('No health logs yet. Tap + to add today.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final sleep = (d['sleepHours'] as num?) ?? 0;
              final exercise = (d['exerciseMinutes'] as num?) ?? 0;
              final mood = ((d['mood'] as num?) ?? 3).toInt().clamp(1, 5);
              return ListTile(
                title: Text(doc.id),
                subtitle: Text(
                    'Sleep ${_num(sleep)} h • Exercise ${_num(exercise)} min'),
                leading: Text(_moods[mood - 1],
                    style: const TextStyle(fontSize: 28)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _service.delete(doc.id),
                ),
                onTap: () => _showForm(context, id: doc.id, existing: d),
              );
            },
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context,
      {String? id, Map<String, dynamic>? existing}) {
    final sleep = TextEditingController(
        text: existing == null ? '' : _num((existing['sleepHours'] as num?) ?? 0));
    final exercise = TextEditingController(
        text: existing == null
            ? ''
            : _num((existing['exerciseMinutes'] as num?) ?? 0));
    var mood = ((existing?['mood'] as num?) ?? 3).toInt().clamp(1, 5);
    var date = id != null ? DateTime.parse(id) : DateTime.now();
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
                      ? null // date is fixed when editing
                      : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setSheet(() => date = picked);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sleep,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Sleep (hours)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exercise,
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
                      label: Text(_moods[i],
                          style: const TextStyle(fontSize: 22)),
                      selected: mood == i + 1,
                      onSelected: (_) => setSheet(() => mood = i + 1),
                    );
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final s = double.tryParse(sleep.text.trim());
                    final e = int.tryParse(exercise.text.trim()) ?? 0;
                    if (s == null || s < 0 || s > 24) {
                      setSheet(() => error = 'Enter sleep between 0 and 24 hours');
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