import 'package:lifemaxxing/screens/plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:lifemaxxing/screens/home_screen.dart';
import 'package:lifemaxxing/services/auth_service.dart';
import 'package:lifemaxxing/screens/wellness_screen.dart';
import 'package:lifemaxxing/screens/finance_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Plan', 'Health', 'Finance', 'Insights'];

    List<Widget> get _pages => [
        HomeScreen(onNavigate: (i) => setState(() => _index = i)),
        const PlanScreen(),
        const WellnessScreen(),
        const FinanceScreen(),
        const _Placeholder('AI Insights'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline), label: 'Health'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Finance'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome), label: 'Insights'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder(this.label);

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('$label (coming soon)'));
}