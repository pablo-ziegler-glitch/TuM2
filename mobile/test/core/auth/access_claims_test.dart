import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/access_claims.dart';

void main() {
  group('AccessClaims.fromTokenClaims', () {
    test('normaliza role y flags owner/admin/super_admin', () {
      final claims = AccessClaims.fromTokenClaims({
        'role': 'SUPER_ADMIN',
        'owner_pending': 'true',
        'admin': false,
        'super_admin': false,
        'access_version': 12,
        'claims_version': 1,
        'claims_updated_at': 1710000000,
      });

      expect(claims.role, 'super_admin');
      expect(claims.ownerPending, isTrue);
      expect(claims.isAdmin, isTrue);
      expect(claims.isSuperAdmin, isTrue);
      expect(claims.accessVersion, 12);
      expect(claims.claimsVersion, 1);
      expect(claims.claimsUpdatedAtSeconds, 1710000000);
    });

    test('fallback seguro ante claims ausentes/malformadas', () {
      final claims = AccessClaims.fromTokenClaims({
        'role': '??',
        'owner_pending': 123,
        'access_version': 'not-a-number',
      });

      expect(claims.role, 'customer');
      expect(claims.ownerPending, isFalse);
      expect(claims.isAdmin, isFalse);
      expect(claims.isSuperAdmin, isFalse);
      expect(claims.accessVersion, isNull);
    });

    test('admin por role aunque flag admin falte', () {
      final claims = AccessClaims.fromTokenClaims({
        'role': 'admin',
        'owner_pending': false,
      });

      expect(claims.role, 'admin');
      expect(claims.isAdmin, isTrue);
      expect(claims.isSuperAdmin, isFalse);
    });
  });
}
