import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantMapsIntent {
  const MerchantMapsIntent({
    required this.uri,
    required this.usedCoordinates,
  });

  final Uri uri;
  final bool usedCoordinates;
}

MerchantMapsIntent buildMerchantMapsIntent({
  required String address,
  double? lat,
  double? lng,
}) {
  final hasCoordinates = lat != null && lng != null;
  final query = hasCoordinates
      ? '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}'
      : (address.trim().isEmpty ? 'Buenos Aires' : address.trim());

  final encodedQuery = Uri.encodeComponent(query);
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
  );

  return MerchantMapsIntent(
    uri: uri,
    usedCoordinates: hasCoordinates,
  );
}

abstract interface class MerchantMapsLauncher {
  Future<bool> open(MerchantMapsIntent intent);
}

class UrlLauncherMerchantMapsLauncher implements MerchantMapsLauncher {
  @override
  Future<bool> open(MerchantMapsIntent intent) async {
    if (!await canLaunchUrl(intent.uri)) return false;
    return launchUrl(
      intent.uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

final merchantMapsLauncherProvider = Provider<MerchantMapsLauncher>(
  (ref) => UrlLauncherMerchantMapsLauncher(),
);
