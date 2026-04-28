import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/copy/brand_copy.dart';

void main() {
  group('BrandCopy', () {
    test('mantiene claim principal canonico', () {
      expect(BrandCopy.primaryClaim, 'Lo que necesitás, en tu zona.');
    });

    test('expone jerarquia base de claims', () {
      expect(BrandCopy.secondaryCampaignClaim, 'Lo útil, a metros.');
      expect(BrandCopy.activationClaim, 'Abrí TuM2 y resolvés.');
      expect(BrandCopy.trustClaim, 'Comercios reales, cerca tuyo.');
    });
  });
}
