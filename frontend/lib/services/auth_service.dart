import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service managing user authentication with Google, GitHub, and local emulator support.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sign in with Google provider.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider();
      if (kIsWeb) {
        return await _auth.signInWithPopup(googleProvider);
      } else {
        return await _auth.signInWithProvider(googleProvider);
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Sign in with GitHub provider with repository and user read scopes.
  Future<UserCredential?> signInWithGithub() async {
    try {
      final githubProvider = GithubAuthProvider();
      githubProvider.addScope('repo');
      githubProvider.addScope('read:user');

      if (kIsWeb) {
        return await _auth.signInWithPopup(githubProvider);
      } else {
        return await _auth.signInWithProvider(githubProvider);
      }
    } catch (e) {
      debugPrint('GitHub sign-in error: $e');
      rethrow;
    }
  }

  /// Quick sign-in helper for local Firebase emulator development.
  /// Automatically creates or signs into a demo account on the Auth emulator.
  Future<UserCredential> signInWithEmulatorDemo({
    String email = 'developer@gitvassal.local',
    String password = 'Password123!',
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
