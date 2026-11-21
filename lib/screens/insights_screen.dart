import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/insights_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _loading = false;
  String? _error;

  static const _border = Color(0xFFE6E9EF);

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await InsightsService().generate();
    } on InsightsException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String domain) {
    switch (domain) {
      case 'productivity':
        return Icons.checklist;
      case 'academic':
        return Icons.school_outlined;
      case 'health':
        return Icons.favorite_outline;
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'habits':
        return Icons.repeat;
      default:
        return Icons.auto_awesome;
    }
  }

    Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return const Color(0xFF111418);
      case 'low':
        return const Color(0xFF9AA3B2);
      default:
        return const Color(0xFF5B6B85);
    }
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recommendations')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Analyses your last 7 days across tasks, habits, health and spending.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'Analysing...' : 'Generate insights'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) return Text('Error: ${snap.error}');
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No insights yet. Tap Generate insights.')),
              );
            }
            final data = snap.data!.docs.first.data();
            final created = (data['createdAt'] as Timestamp?)?.toDate();
            final items = ((data['items'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((data['summary'] ?? '').toString().isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your week',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(data['summary'] as String),
                        if (created != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Generated ${created.day}/${created.month}/${created.year} '
                            '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ),
                for (final r in items)
                  _card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_icon((r['domain'] ?? 'general') as String)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text((r['title'] ?? '') as String,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15)),
                                  ),
                                  Text(
                                    ((r['priority'] ?? 'medium') as String)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _priorityColor(
                                          (r['priority'] ?? 'medium')
                                              as String),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text((r['detail'] ?? '') as String),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'AI-generated suggestions based on your logged data. '
                    'Not professional health or financial advice.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}