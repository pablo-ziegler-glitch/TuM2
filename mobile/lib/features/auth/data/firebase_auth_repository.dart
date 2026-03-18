import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';

/// Concrete Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;

  FirebaseAuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Update display name on the Firebase Auth profile
    await credential.user?.updateDisplayName(displayName.trim());
    return credential;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
