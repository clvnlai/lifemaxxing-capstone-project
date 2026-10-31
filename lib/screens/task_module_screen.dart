import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

class TaskModuleScreen extends StatelessWidget {
  final String collection;
  final String singular;
  final bool hasSubject;
  final DataService _service;

  TaskModuleScreen({
    super.key,
    required this.collection,
    required this.singular,
    this.hasSubject = false,
  }) : _service = DataService(collection);

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.stream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No ${singular}s yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final done = d['done'] == true;
              final due = (d['dueDate'] as Timestamp?)?.toDate();
              final subject = (d['subject'] ?? '') as String;
              final parts = <String>[
                if (hasSubject && subject.isNotEmpty) subject,
                if (due != null) 'Due ${_fmt(due)}',
              ];
              return ListTile(
                leading: Checkbox(
                  value: done,
                  onChanged: (v) =>
                      _service.update(doc.id, {'done': v ?? false}),
                ),
                title: Text(
                  (d['title'] ?? '') as String,
                  style: TextStyle(
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: parts.isEmpty ? null : Text(parts.join(' • ')),
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
    final title = TextEditingController(text: (existing?['title'] ?? '') as String);
    final subject =
        TextEditingController(text: (existing?['subject'] ?? '') as String);
    DateTime? due = (existing?['dueDate'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(id == null ? 'New $singular' : 'Edit $singular',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              if (hasSubject) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(
                      labelText: 'Subject', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(due == null ? 'Set due date' : 'Due ${_fmt(due!)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: due ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setSheet(() => due = picked);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final data = <String, dynamic>{
                    'title': title.text.trim(),
                    if (hasSubject) 'subject': subject.text.trim(),
                    'dueDate': due == null ? null : Timestamp.fromDate(due!),
                  };
                  if (id == null) {
                    await _service.add({...data, 'done': false});
                  } else {
                    await _service.update(id, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}