import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminSession extends ChangeNotifier {
  AdminSession._() {
    _subscription = FirebaseAuth.instance.idTokenChanges().listen((user) {
      unawaited(_refreshFromUser(user));
    });
  }

  static final AdminSession instance = AdminSession._();

  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _loading = true;
  String _role = '';

  bool get isLoading => _loading;
  User? get user => _user;
  String get role => _role;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _role == 'admin' || _role == 'super_admin';

  Future<void> ensureLoaded() async {
    if (!_loading) return;
    await _refreshFromUser(FirebaseAuth.instance.currentUser);
  }

  Future<void> refreshClaims() async {
    await _refreshFromUser(FirebaseAuth.instance.currentUser,
        forceRefresh: true);
  }

  Future<void> _refreshFromUser(
    User? user, {
    bool forceRefresh = false,
  }) async {
    _user = user;
    if (user == null) {
      _role = '';
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      final nextRole =
          (token.claims?['role'] as String? ?? '').trim().toLowerCase();
      _role = nextRole;
    } catch (_) {
      _role = '';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
