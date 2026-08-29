import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with gitvassal options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to local Firebase Emulators if in debug mode or localhost
  if (kDebugMode || const bool.fromEnvironment('USE_EMULATOR', defaultValue: false)) {
    try {
      const host = '127.0.0.1';
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      debugPrint('Connected to Firebase Emulators (Auth: 9099, Firestore: 8080)');
    } catch (e) {
      debugPrint('Emulator setup notice: $e');
    }
  }

  runApp(const TaskVassalApp());
}

class TaskVassalApp extends StatelessWidget {
  const TaskVassalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        title: 'TaskVassal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Authentication Gate: displays DashboardScreen when authenticated, AuthScreen otherwise.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return DashboardScreen(user: user);
        }

        return const AuthScreen();
      },
    );
  }
}
