import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_claim/models/merchant_claim_models.dart';

void main() {
  group('MerchantClaimStatusX', () {
    test('mapea estado api -> enum', () {
      expect(
        MerchantClaimStatusX.fromApi('needs_more_info'),
        MerchantClaimStatus.needsMoreInfo,
      );
      expect(
        MerchantClaimStatusX.fromApi('conflict_detected'),
        MerchantClaimStatus.conflictDetected,
      );
    });

    test('mapea enum -> estado api', () {
      expect(
        MerchantClaimStatus.underReview.apiValue,
        'under_review',
      );
      expect(
        MerchantClaimStatus.duplicateClaim.apiValue,
        'duplicate_claim',
      );
    });
  });

  group('MerchantClaimEvidenceFile', () {
    test('serializa payload para callable', () {
      const file = MerchantClaimEvidenceFile(
        id: 'storefront_1',
        kind: MerchantClaimEvidenceKind.storefrontPhoto,
        storagePath: 'merchant-claims/u1/c1/storefront_photo/file.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1024,
        originalFileName: 'fachada.jpg',
      );

      final payload = file.toPayload();
      expect(payload['id'], 'storefront_1');
      expect(payload['kind'], 'storefront_photo');
      expect(payload['sizeBytes'], 1024);
    });
  });
}
