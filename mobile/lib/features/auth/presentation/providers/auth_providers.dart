import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase_auth_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/auth_repository.dart';
import '../../domain/user_model.dart';

// ── Repositories ────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// ── Auth state ───────────────────────────────────────────────────────────────

/// Stream of Firebase Auth user state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current authenticated Firebase user (sync, nullable).
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Current TuM2 user document from Firestore (streamed).
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return Stream.value(null);

  return ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);
});

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;

  AuthNotifier(this._authRepo, this._userRepo)
      : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authRepo.signInWithEmailPassword(email, password),
    );
  }

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authRepo.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = const AsyncValue.data(null);
      return credential.user?.uid;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_authRepo.signOut);
  }

  Future<void> selectRole(String uid, RoleType role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _userRepo.updateRole(uid, role),
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _authRepo.sendPasswordResetEmail(email);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});
