import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flags_provider.dart';

class LegalDocumentsConfig {
  const LegalDocumentsConfig({
    required this.termsUri,
    required this.privacyUri,
    required this.claimConsentUri,
    required this.version,
  });

  final Uri termsUri;
  final Uri privacyUri;
  final Uri claimConsentUri;
  final String version;
}

const _defaultTermsUrl = 'https://tum2.app/terminos';
const _defaultPrivacyUrl = 'https://tum2.app/privacidad';
const _defaultClaimConsentUrl = 'https://tum2.app/claim-consentimiento';
const _defaultLegalDocsVersion = 'v1';

final legalDocumentsConfigProvider = FutureProvider<LegalDocumentsConfig>((
  ref,
) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'legal_terms_url': _defaultTermsUrl,
      'legal_privacy_url': _defaultPrivacyUrl,
      'legal_claim_consent_url': _defaultClaimConsentUrl,
      'legal_docs_version': _defaultLegalDocsVersion,
    });
    await remoteConfig.fetchAndActivate();
  } catch (_) {
    // Fallback silencioso a defaults.
  }

  final termsUrl = _safeUrl(
    remoteConfig.getString('legal_terms_url'),
    fallback: _defaultTermsUrl,
  );
  final privacyUrl = _safeUrl(
    remoteConfig.getString('legal_privacy_url'),
    fallback: _defaultPrivacyUrl,
  );
  final claimConsentUrl = _safeUrl(
    remoteConfig.getString('legal_claim_consent_url'),
    fallback: _defaultClaimConsentUrl,
  );
  final version = _safeVersion(remoteConfig.getString('legal_docs_version'));

  return LegalDocumentsConfig(
    termsUri: Uri.parse(termsUrl),
    privacyUri: Uri.parse(privacyUrl),
    claimConsentUri: Uri.parse(claimConsentUrl),
    version: version,
  );
});

String _safeUrl(String? value, {required String fallback}) {
  final normalized = (value ?? '').trim();
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return normalized;
  }
  return fallback;
}

String _safeVersion(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) return _defaultLegalDocsVersion;
  return normalized;
}
