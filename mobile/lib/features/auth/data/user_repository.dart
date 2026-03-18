import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_model.dart';

/// Firestore operations for the `users` collection.
class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('users');

  /// Streams the user document for [uid].
  Stream<UserModel?> watchUser(String uid) {
    return _collection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  /// Fetches the user document for [uid] once.
  Future<UserModel?> getUser(String uid) async {
    final snap = await _collection.doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  /// Updates the role type for [uid].
  Future<void> updateRole(String uid, RoleType role) async {
    final roleString = _roleToString(role);
    await _collection.doc(uid).update({'roleType': roleString});
  }

  /// Updates arbitrary fields on the user document.
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _collection.doc(uid).update(fields);
  }

  static String _roleToString(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return 'OWNER';
      case RoleType.customer:
        return 'CUSTOMER';
      case RoleType.admin:
        return 'ADMIN';
    }
  }
}
