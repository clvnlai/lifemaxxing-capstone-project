import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/services/auth_service.dart';
import 'package:lifemaxxing/services/demo_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  final _db = FirebaseFirestore.instance;
  bool _busy = false;

  static const _collections = [
    'tasks',
    'assignments',
    'habits',
    'habitLogs',
    'healthLogs',
    'transactions',
    'recommendations',
  ];

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _editName(String current) async {
    final c = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _user.updateDisplayName(name);
    await _db.collection('users').doc(_user.uid).update({'name': name});
    _snack('Name updated');
  }

  Future<void> _resetPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _user.email!);
      _snack('Password reset email sent to ${_user.email}');
    } on FirebaseAuthException catch (e) {
      _snack('Could not send email (${e.code})');
    }
  }

  Future<void> _loadDemo() async {
    final s = await showDialog<DemoScenario>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Load sample data'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
                'Fills the last 7 days with example tasks, habits, health and '
                'spending. It overwrites your health logs for those days.'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, DemoScenario.lowSleepOverspending),
            child: const Text('Low sleep and overspending week'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, DemoScenario.balanced),
            child: const Text('Balanced week'),
          ),
        ],
      ),
    );
    if (s == null) return;
    setState(() => _busy = true);
    try {
      await DemoData.load(s);
      _snack('Sample data loaded');
    } catch (_) {
      _snack('Could not load sample data');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearDemo() async {
    setState(() => _busy = true);
    try {
      await DemoData.clear();
      _snack('Sample data removed');
    } catch (_) {
      _snack('Could not remove sample data');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteAccount() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This permanently deletes your account and all your data. '
                'Enter your password to confirm.'),
            const SizedBox(height: 12),
            TextField(
              controller: pw,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: _user.email!, password: pw.text),
      );
      final userDoc = _db.collection('users').doc(_user.uid);
      for (final c in _collections) {
        await _deleteCollection(userDoc.collection(c));
      }
      await userDoc.delete();
      await _user.delete();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'invalid-credential' || e.code == 'wrong-password'
          ? 'Incorrect password.'
          : 'Could not delete account (${e.code}).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(_user.uid).snapshots(),
        builder: (context, snap) {
          final name = (snap.data?.data()?['name'] as String?) ??
              _user.displayName ??
              '';
          return ListView(
            children: [
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 36,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                  child: Text(name,
                      style: Theme.of(context).textTheme.titleLarge)),
              Center(child: Text(_user.email ?? '')),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit name'),
                onTap: _busy ? null : () => _editName(name),
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Send password reset email'),
                onTap: _busy ? null : _resetPassword,
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: _busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        AuthService().signOut();
                      },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Load sample data'),
                subtitle: const Text('Try the app without typing everything in'),
                onTap: _busy ? null : _loadDemo,
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Remove sample data'),
                onTap: _busy ? null : _clearDemo,
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: error),
                title: Text('Delete account and data',
                    style: TextStyle(color: error)),
                onTap: _busy ? null : _deleteAccount,
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}