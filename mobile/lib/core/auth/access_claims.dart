class AccessClaims {
  const AccessClaims({
    required this.role,
    required this.ownerPending,
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.accessVersion,
    required this.claimsVersion,
    required this.claimsUpdatedAtSeconds,
  });

  final String role;
  final bool ownerPending;
  final bool isAdmin;
  final bool isSuperAdmin;
  final int? accessVersion;
  final int? claimsVersion;
  final int? claimsUpdatedAtSeconds;

  factory AccessClaims.fromTokenClaims(Map<String, dynamic>? claims) {
    final raw = claims ?? const <String, dynamic>{};
    final role = _normalizeRole(raw['role']);
    final isSuperAdmin = _readBool(raw['super_admin']) || role == 'super_admin';
    final isAdmin =
        _readBool(raw['admin']) || role == 'admin' || role == 'super_admin';
    return AccessClaims(
      role: role,
      ownerPending: _readBool(raw['owner_pending']),
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
      accessVersion: _readNonNegativeInt(raw['access_version']),
      claimsVersion: _readNonNegativeInt(raw['claims_version']),
      claimsUpdatedAtSeconds: _readNonNegativeInt(raw['claims_updated_at']),
    );
  }
}

String _normalizeRole(Object? raw) {
  if (raw is! String) return 'customer';
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'owner') return 'owner';
  if (normalized == 'admin') return 'admin';
  if (normalized == 'super_admin') return 'super_admin';
  return 'customer';
}

bool _readBool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is String) return raw.trim().toLowerCase() == 'true';
  return false;
}

int? _readNonNegativeInt(Object? raw) {
  if (raw is int && raw >= 0) return raw;
  if (raw is num && raw >= 0 && raw == raw.toInt()) return raw.toInt();
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null && parsed >= 0) return parsed;
  }
  return null;
}
