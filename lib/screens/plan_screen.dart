import 'package:flutter/material.dart';
import 'package:lifemaxxing/screens/task_module_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Productivity'), Tab(text: 'Academic')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TaskModuleScreen(collection: 'tasks', singular: 'task'),
                TaskModuleScreen(
                  collection: 'assignments',
                  singular: 'assignment',
                  hasSubject: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}