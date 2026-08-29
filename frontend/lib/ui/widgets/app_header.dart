import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'settings_dialog.dart';

/// Top application navigation bar matching the TaskVassal header design.
class AppHeader extends StatelessWidget {
  final User user;
  final VoidCallback? onMenuToggle;

  const AppHeader({
    super.key,
    required this.user,
    this.onMenuToggle,
  });

  void _openNewIssue(BuildContext context) async {
    // If user has a monitored repo or default, open GitHub new issue page
    final Uri url = Uri.parse('https://github.com/issues');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (onMenuToggle != null) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
              onPressed: onMenuToggle,
              tooltip: 'Toggle Menu',
            ),
            const SizedBox(width: 8),
          ],

          // Brand Logo & Title
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.task_alt,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TaskVassal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),

          const SizedBox(width: 32),

          // Navigation Tabs: Dashboard, Issues, Pull Requests
          _buildNavTab(
            context: context,
            tab: NavTab.dashboard,
            label: 'Dashboard',
            isSelected: appState.selectedTab == NavTab.dashboard,
            onTap: () => appState.setSelectedTab(NavTab.dashboard),
          ),
          const SizedBox(width: 20),
          _buildNavTab(
            context: context,
            tab: NavTab.issues,
            label: 'Issues',
            isSelected: appState.selectedTab == NavTab.issues,
            onTap: () => appState.setSelectedTab(NavTab.issues),
          ),
          const SizedBox(width: 20),
          _buildNavTab(
            context: context,
            tab: NavTab.pullRequests,
            label: 'Pull Requests',
            isSelected: appState.selectedTab == NavTab.pullRequests,
            onTap: () => appState.setSelectedTab(NavTab.pullRequests),
          ),

          const Spacer(),

          // Search Bar
          SizedBox(
            width: 240,
            height: 36,
            child: TextField(
              onChanged: (value) => appState.setSearchQuery(value),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textPlaceholder),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.borderMedium),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // New Issue Button
          ElevatedButton.icon(
            onPressed: () => _openNewIssue(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Issue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Notifications Bell Icon
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No unread notifications.')),
              );
            },
            tooltip: 'Notifications',
          ),

          // Settings Gear Icon
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 20),
            onPressed: () => SettingsDialog.show(context, user.uid),
            tooltip: 'Settings',
          ),

          const SizedBox(width: 8),

          // User Avatar & Dropdown Menu
          PopupMenuButton<String>(
            tooltip: 'Account Settings',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (value) {
              if (value == 'settings') {
                SettingsDialog.show(context, user.uid);
              } else if (value == 'logout') {
                context.read<AuthService>().signOut();
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null
                  ? Text(
                      (user.email ?? user.displayName ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : null,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'Authenticated User',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      user.email ?? user.uid,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppTheme.dotRed),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(color: AppTheme.dotRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required BuildContext context,
    required NavTab tab,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
