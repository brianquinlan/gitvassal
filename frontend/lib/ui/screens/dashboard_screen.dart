import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_header.dart';
import '../widgets/task_table.dart';

/// Main Dashboard Screen displaying the dynamic TaskVassal scrollable list directly under the top bar.
class DashboardScreen extends StatelessWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Header with App Title, Settings Icon, and User Profile Icon
            AppHeader(user: user),

            // Dynamic on-demand scrollable task list
            Expanded(
              child: TaskTable(
                uid: user.uid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
