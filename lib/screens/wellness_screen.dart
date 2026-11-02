import 'package:flutter/material.dart';
import 'package:lifemaxxing/screens/habits_screen.dart';
import 'package:lifemaxxing/screens/health_screen.dart';

class WellnessScreen extends StatelessWidget {
  const WellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Habits'), Tab(text: 'Health')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                HabitsScreen(),
                HealthScreen()              ],
            ),
          ),
        ],
      ),
    );
  }
}