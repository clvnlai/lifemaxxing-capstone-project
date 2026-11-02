import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/data_service.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  static final _service = DataService('transactions');

  static const _expenseCats = [
    'Food',
    'Transport',
    'Study',
    'Bills',
    'Shopping',
    'Entertainment',
    'Health',
    'Other',
  ];
  static const _incomeCats = ['Allowance', 'Salary', 'Other'];

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  static String _money(num n) => 'RM ${n.toStringAsFixed(2)}';
  static String _plain(num n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            ..sort((a, b) {
              final ad = (a.data()['date'] as Timestamp?)?.toDate() ??
                  DateTime(2000);
              final bd = (b.data()['date'] as Timestamp?)?.toDate() ??
                  DateTime(2000);
              return bd.compareTo(ad);
            });
          if (docs.isEmpty) {
            return const Center(
                child: Text('No transactions yet. Tap + to add one.'));
          }

          final now = DateTime.now();
          double income = 0, expense = 0;
          for (final d in docs) {
            final m = d.data();
            final dt = (m['date'] as Timestamp?)?.toDate();
            if (dt == null || dt.year != now.year || dt.month != now.month) {
              continue;
            }
            final amt = (m['amount'] as num?)?.toDouble() ?? 0;
            if (m['type'] == 'income') {
              income += amt;
            } else {
              expense += amt;
            }
          }

          return ListView.builder(
            itemCount: docs.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This month',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Income: ${_money(income)}'),
                        Text('Expenses: ${_money(expense)}'),
                        Text('Balance: ${_money(income - expense)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              final doc = docs[i - 1];
              final d = doc.data();
              final isIncome = d['type'] == 'income';
              final amount = (d['amount'] as num?) ?? 0;
              final dt = (d['date'] as Timestamp?)?.toDate();
              final note = (d['note'] ?? '') as String;
              return ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : scheme.error,
                ),
                title: Text((d['category'] ?? '') as String),
                subtitle: Text([
                  if (dt != null) _fmtDate(dt),
                  if (note.isNotEmpty) note,
                ].join(' • ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}${_money(amount)}',
                      style: TextStyle(
                          color: isIncome ? Colors.green : scheme.error,
                          fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _service.delete(doc.id),
                    ),
                  ],
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
    final amount = TextEditingController(
        text: existing == null
            ? ''
            : _plain((existing['amount'] as num?) ?? 0));
    final note =
        TextEditingController(text: (existing?['note'] ?? '') as String);
    var type = (existing?['type'] ?? 'expense') as String;
    var category = (existing?['category'] ?? 'Food') as String;
    var date = (existing?['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final cats = type == 'income' ? _incomeCats : _expenseCats;
          if (!cats.contains(category)) category = cats.first;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(id == null ? 'New transaction' : 'Edit transaction',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                      ButtonSegment(value: 'income', label: Text('Income')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setSheet(() {
                      type = s.first;
                      category =
                          (type == 'income' ? _incomeCats : _expenseCats)
                              .first;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount (RM)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in cats)
                        ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setSheet(() => category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_fmtDate(date)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheet(() => date = picked);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final a = double.tryParse(amount.text.trim());
                      if (a == null || a <= 0) {
                        setSheet(() => error = 'Enter an amount above 0');
                        return;
                      }
                      final data = <String, dynamic>{
                        'type': type,
                        'amount': a,
                        'category': category,
                        'note': note.text.trim(),
                        'date': Timestamp.fromDate(date),
                      };
                      if (id == null) {
                        await _service.add(data);
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
          );
        },
      ),
    );
  }
}