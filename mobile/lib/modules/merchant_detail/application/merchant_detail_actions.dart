import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/merchant_maps.dart';

abstract interface class MerchantDetailActions {
  Future<bool> openCall(String phone);

  Future<bool> openWhatsApp(String phone);

  Future<bool> openDirections({
    required String address,
    double? lat,
    double? lng,
    String? mapsUrl,
  });

  Future<bool> shareMerchant({
    required String merchantId,
    required String merchantName,
  });
}

class DefaultMerchantDetailActions implements MerchantDetailActions {
  const DefaultMerchantDetailActions({
    required MerchantMapsLauncher mapsLauncher,
  }) : _mapsLauncher = mapsLauncher;

  final MerchantMapsLauncher _mapsLauncher;

  @override
  Future<bool> openCall(String phone) async {
    final cleaned = _normalizePhone(phone);
    if (cleaned.isEmpty) return false;
    final uri = Uri.parse('tel:$cleaned');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> openWhatsApp(String phone) async {
    final cleaned = _normalizePhone(phone);
    if (cleaned.isEmpty) return false;
    final digitsOnly = cleaned.replaceAll('+', '');
    if (digitsOnly.isEmpty) return false;
    final uri = Uri.parse('https://wa.me/$digitsOnly');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> openDirections({
    required String address,
    double? lat,
    double? lng,
    String? mapsUrl,
  }) async {
    final directUrl = mapsUrl?.trim() ?? '';
    if (directUrl.isNotEmpty) {
      final uri = Uri.tryParse(directUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    final intent = buildMerchantMapsIntent(
      address: address,
      lat: lat,
      lng: lng,
    );
    return _mapsLauncher.open(intent);
  }

  @override
  Future<bool> shareMerchant({
    required String merchantId,
    required String merchantName,
  }) async {
    // Fallback sin share sheet: copiamos un link canónico al portapapeles.
    final deepLink = 'https://tum2.app/commerce/$merchantId';
    await Clipboard.setData(
      ClipboardData(
        text: '$merchantName\n$deepLink',
      ),
    );
    return true;
  }

  String _normalizePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits == '+') return '';
    return digits;
  }
}

final merchantDetailActionsProvider = Provider<MerchantDetailActions>((ref) {
  return DefaultMerchantDetailActions(
    mapsLauncher: ref.watch(merchantMapsLauncherProvider),
  );
});
