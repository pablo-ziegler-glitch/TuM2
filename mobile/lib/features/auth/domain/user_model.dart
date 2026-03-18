import 'package:cloud_firestore/cloud_firestore.dart';

enum RoleType { owner, customer, admin }

enum RankType { vecino, explorador, referente, conector, radar }

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final RoleType? roleType;
  final String currentRank;
  final int xpPoints;
  final String status;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.roleType,
    required this.currentRank,
    required this.xpPoints,
    required this.status,
    required this.createdAt,
  });

  bool get isOwner => roleType == RoleType.owner;
  bool get isCustomer => roleType == RoleType.customer;
  bool get isAdmin => roleType == RoleType.admin;
  bool get needsRoleSelection => roleType == null;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      roleType: _parseRole(data['roleType'] as String?),
      currentRank: data['currentRank'] as String? ?? 'Vecino',
      xpPoints: data['xpPoints'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'roleType': _roleToString(roleType),
        'currentRank': currentRank,
        'xpPoints': xpPoints,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? displayName,
    RoleType? roleType,
    String? currentRank,
    int? xpPoints,
    String? status,
  }) =>
      UserModel(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        roleType: roleType ?? this.roleType,
        currentRank: currentRank ?? this.currentRank,
        xpPoints: xpPoints ?? this.xpPoints,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  static RoleType? _parseRole(String? value) {
    switch (value) {
      case 'OWNER':
        return RoleType.owner;
      case 'CUSTOMER':
        return RoleType.customer;
      case 'ADMIN':
        return RoleType.admin;
      default:
        return null;
    }
  }

  static String? _roleToString(RoleType? role) {
    switch (role) {
      case RoleType.owner:
        return 'OWNER';
      case RoleType.customer:
        return 'CUSTOMER';
      case RoleType.admin:
        return 'ADMIN';
      default:
        return null;
    }
  }
}
