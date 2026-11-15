import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class InsightsException implements Exception {
  final String message;
  InsightsException(this.message);
  @override
  String toString() => message;
}

class InsightsService {
  // If you get a "model not found" error, pick a current stable Flash or
  // Flash-Lite model from https://firebase.google.com/docs/ai-logic/models
  static const _model = 'gemini-3.5-flash-lite';
  static const _domains = [
    'productivity',
    'academic',
    'health',
    'finance',
    'habits',
    'general'
  ];
  static const _priorities = ['high', 'medium', 'low'];

  final _db = FirebaseFirestore.instance;

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double? _avg(List<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

  static double? _r(double? n, [int p = 1]) {
    if (n == null) return null;
    final f = pow(10, p).toDouble();
    return (n * f).round() / f;
  }

  static double _n(dynamic v) => v is num ? v.toDouble() : 0.0;

  Future<List<Map<String, dynamic>>> _read(String uid, String name) async {
    final snap = await _db.collection('users').doc(uid).collection(name).get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  Future<void> generate() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final recCol =
        _db.collection('users').doc(uid).collection('recommendations');

    // Simple rate limit: one request per 30 seconds
    final last =
        await recCol.orderBy('createdAt', descending: true).limit(1).get();
    if (last.docs.isNotEmpty) {
      final t = (last.docs.first.data()['createdAt'] as Timestamp?)?.toDate();
      if (t != null && DateTime.now().difference(t).inSeconds < 30) {
        throw InsightsException(
            'Please wait a few seconds before generating again.');
      }
    }

    final built = await _buildSummary(uid);
    if (built.records == 0) {
      throw InsightsException(
          'Log some tasks, habits, health or spending first, then try again.');
    }
    final summary = built.summary;

    final prompt = '''
You are the insight engine of LifeMaxxing, a personal development app for Malaysian university students and young professionals.

Below is a summary of the user's last 7 days across productivity, academics, habits, health and finance. Money is in Malaysian Ringgit (RM). A null value means no data was logged.

DATA:
${jsonEncode(summary)}

Write personalised, practical recommendations.

RULES:
- Use only the numbers in DATA. Never invent figures.
- Prefer insights that connect two or more areas (see "crossDomain" when present).
- If data is thin, say so and suggest what to log next.
- Be supportive and specific. Do not give medical, mental-health or investment advice. For health or money topics, keep it to everyday habits.
- Give 3 or 4 recommendations, each with one concrete next step.

Reply with ONLY valid JSON in exactly this shape:
{"summary":"2 sentences describing the week","recommendations":[{"title":"short title","detail":"1-3 sentences, with one concrete action","domain":"productivity|academic|health|finance|habits|general","priority":"high|medium|low"}]}
''';

    final model = FirebaseAI.googleAI().generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4,
      ),
    );

    String text;
    try {
      final res = await model.generateContent([Content.text(prompt)]);
      text = res.text ?? '';
    } catch (e) {
      debugPrint('Gemini error: $e');
      throw InsightsException(
          'The AI service is unavailable right now. Please try again.');
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text.replaceAll(RegExp(r'```json|```'), '').trim())
          as Map<String, dynamic>;
    } catch (_) {
      debugPrint('Unreadable AI response: $text');
      throw InsightsException(
          'The AI response was unreadable. Please try again.');
    }

    String cut(dynamic v, int max) {
      final s = (v ?? '').toString();
      return s.length > max ? s.substring(0, max) : s;
    }

    final items = ((parsed['recommendations'] as List?) ?? [])
        .take(4)
        .map((e) {
          final r = Map<String, dynamic>.from(e as Map);
          return {
            'title': cut(r['title'], 80),
            'detail': cut(r['detail'], 400),
            'domain': _domains.contains(r['domain']) ? r['domain'] : 'general',
            'priority':
                _priorities.contains(r['priority']) ? r['priority'] : 'medium',
          };
        })
        .where((r) =>
            (r['title'] as String).isNotEmpty &&
            (r['detail'] as String).isNotEmpty)
        .toList();

    if (items.isEmpty) {
      throw InsightsException(
          'The AI returned no recommendations. Please try again.');
    }

    await recCol.add({
      'summary': cut(parsed['summary'], 400),
      'items': items,
      'stats': summary,
      'model': _model,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<({int records, Map<String, dynamic> summary})> _buildSummary(
      String uid) async {
    final results = await Future.wait(
      ['tasks', 'assignments', 'habits', 'habitLogs', 'healthLogs', 'transactions']
          .map((c) => _read(uid, c)),
    );
    final tasks = results[0];
    final assignments = results[1];
    final habits = results[2];
    final habitLogs = results[3];
    final health = results[4];
    final tx = results[5];

    final now = DateTime.now();
    final days =
        List.generate(7, (i) => _key(now.subtract(Duration(days: 6 - i))));
    final daySet = days.toSet();
    final today = days.last;
    final in7 = _key(now.add(const Duration(days: 7)));

    String? tk(dynamic ts) => ts is Timestamp ? _key(ts.toDate()) : null;

    // Health
    final healthByDay = <String, Map<String, dynamic>>{};
    for (final h in health) {
      if (daySet.contains(h['id'])) healthByDay[h['id'] as String] = h;
    }
    final hl = healthByDay.values.toList();

    // Habits
    final habitIds = habits.map((h) => h['id'] as String).toSet();
    final logsInWindow = habitLogs
        .where((l) =>
            daySet.contains(l['date']) && habitIds.contains(l['habitId']))
        .toList();
    final habitsByDay = <String, int>{};
    for (final l in logsInWindow) {
      final d = l['date'] as String;
      habitsByDay[d] = (habitsByDay[d] ?? 0) + 1;
    }

    // Tasks and assignments
    final openTasks = tasks.where((t) => t['done'] != true).toList();
    final openAssign = assignments.where((a) => a['done'] != true).toList();
    int overdue(List<Map<String, dynamic>> l) => l.where((t) {
          final k = tk(t['dueDate']);
          return k != null && k.compareTo(today) < 0;
        }).length;
    final dueSoon = openAssign.where((a) {
      final k = tk(a['dueDate']);
      return k != null && k.compareTo(today) >= 0 && k.compareTo(in7) <= 0;
    }).length;

    // Finance
    final expenses = tx
        .where((t) => t['type'] != 'income' && daySet.contains(tk(t['date'])))
        .toList();
    final incomes = tx
        .where((t) => t['type'] == 'income' && daySet.contains(tk(t['date'])))
        .toList();
    final spendByDay = <String, double>{};
    final byCat = <String, double>{};
    for (final t in expenses) {
      final k = tk(t['date'])!;
      final amt = _n(t['amount']);
      spendByDay[k] = (spendByDay[k] ?? 0) + amt;
      final c = (t['category'] ?? 'Other') as String;
      byCat[c] = (byCat[c] ?? 0) + amt;
    }
    final top = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Cross-domain signals, calculated here so they are real numbers
    final low = days
        .where((d) =>
            healthByDay[d] != null && _n(healthByDay[d]!['sleepHours']) < 6.5)
        .toList();
    final ok = days
        .where((d) =>
            healthByDay[d] != null && _n(healthByDay[d]!['sleepHours']) >= 6.5)
        .toList();
    Map<String, dynamic>? cross;
    if (low.length >= 2 && ok.length >= 2) {
      double? spend(List<String> ds) =>
          _r(_avg(ds.map((d) => spendByDay[d] ?? 0.0).toList()), 2);
      double? hab(List<String> ds) =>
          _r(_avg(ds.map((d) => (habitsByDay[d] ?? 0).toDouble()).toList()));
      double? mood(List<String> ds) => _r(_avg(ds
          .map((d) => healthByDay[d]!['mood'] == null
              ? 3.0
              : _n(healthByDay[d]!['mood']))
          .toList()));
      cross = {
        'note':
            'Compares days with under 6.5 h sleep against days with 6.5 h or more.',
        'lowSleepDays': low.length,
        'normalSleepDays': ok.length,
        'avgSpendingRM': {'lowSleep': spend(low), 'normalSleep': spend(ok)},
        'avgHabitsCompletedPerDay': {
          'lowSleep': hab(low),
          'normalSleep': hab(ok)
        },
        'avgMood': {'lowSleep': mood(low), 'normalSleep': mood(ok)},
      };
    }

    final records = hl.length +
        logsInWindow.length +
        expenses.length +
        incomes.length +
        tasks.length +
        assignments.length;

    double sum(List<Map<String, dynamic>> l) =>
        l.fold<double>(0, (s, t) => s + _n(t['amount']));

    final summary = <String, dynamic>{
      'period': '${days.first} to ${days.last}',
      'health': {
        'daysLogged': hl.length,
        'avgSleepHours': _r(_avg(hl.map((h) => _n(h['sleepHours'])).toList())),
        'avgExerciseMinutes':
            _r(_avg(hl.map((h) => _n(h['exerciseMinutes'])).toList()), 0),
        'avgMoodOutOf5': _r(_avg(hl
            .map((h) => h['mood'] == null ? 3.0 : _n(h['mood']))
            .toList())),
        'sleepByDay': days
            .map((d) => healthByDay[d] == null
                ? null
                : _n(healthByDay[d]!['sleepHours']))
            .toList(),
      },
      'habits': {
        'totalHabits': habits.length,
        'completionsLast7Days': logsInWindow.length,
        'completionRatePercent': habits.isEmpty
            ? null
            : (logsInWindow.length / (habits.length * 7) * 100).round(),
      },
      'productivity': {
        'openTasks': openTasks.length,
        'overdueTasks': overdue(openTasks),
        'completedTasksTotal': tasks.length - openTasks.length,
      },
      'academic': {
        'openAssignments': openAssign.length,
        'overdueAssignments': overdue(openAssign),
        'dueWithin7Days': dueSoon,
      },
      'finance': {
        'spentRM': _r(sum(expenses), 2),
        'incomeRM': _r(sum(incomes), 2),
        'topCategories': top
            .take(3)
            .map((e) => {'category': e.key, 'amountRM': _r(e.value, 2)})
            .toList(),
        'spendingByDayRM':
            days.map((d) => _r(spendByDay[d] ?? 0.0, 2)).toList(),
      },
      'crossDomain': cross,
    };

    return (records: records, summary: summary);
  }
}