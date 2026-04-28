import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/providers/feature_flags_provider.dart';

void main() {
  group('resolveSplashBrandVariant', () {
    test('retorna worldcup cuando mobile_worldcup_enabled=true', () {
      final result = resolveSplashBrandVariant(
        rawVariant: 'original',
        worldcupEnabled: true,
      );

      expect(result, SplashBrandVariant.worldcup);
    });

    test('retorna worldcup cuando splash_brand_variant=mundialista', () {
      final result = resolveSplashBrandVariant(
        rawVariant: 'mundialista',
        worldcupEnabled: false,
      );

      expect(result, SplashBrandVariant.worldcup);
    });

    test('retorna worldcup cuando splash_brand_variant=worldcup', () {
      final result = resolveSplashBrandVariant(
        rawVariant: 'worldcup',
        worldcupEnabled: false,
      );

      expect(result, SplashBrandVariant.worldcup);
    });

    test('normaliza espacios y mayusculas', () {
      final result = resolveSplashBrandVariant(
        rawVariant: '  MunDialista  ',
        worldcupEnabled: false,
      );

      expect(result, SplashBrandVariant.worldcup);
    });

    test('retorna original para valor no soportado', () {
      final result = resolveSplashBrandVariant(
        rawVariant: 'original',
        worldcupEnabled: false,
      );

      expect(result, SplashBrandVariant.original);
    });
  });
}
