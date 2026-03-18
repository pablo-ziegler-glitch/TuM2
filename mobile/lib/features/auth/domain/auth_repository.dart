import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Stream of Firebase Auth user changes.
  Stream<User?> get authStateChanges;

  /// Current authenticated user (nullable).
  User? get currentUser;

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmailPassword(String email, String password);

  /// Registers a new user with email, password, and display name.
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  });

  /// Signs out the current user.
  Future<void> signOut();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);
}
