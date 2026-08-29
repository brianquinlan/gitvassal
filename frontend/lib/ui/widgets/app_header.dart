import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../theme.dart';
import 'settings_dialog.dart';

/// Top application header bar containing only the settings icon and user profile icon.
class AppHeader extends StatelessWidget {
  final User user;
  final VoidCallback? onMenuToggle;

  const AppHeader({
    super.key,
    required this.user,
    this.onMenuToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
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
          ],

          const Spacer(),

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
}
