import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/analytics_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/pharmacy_duty_item.dart';

class PharmacyDutyDetailScreen extends StatelessWidget {
  const PharmacyDutyDetailScreen({
    super.key,
    required this.pharmacyId,
    this.item,
  });

  final String pharmacyId;
  final PharmacyDutyItem? item;

  @override
  Widget build(BuildContext context) {
    if (item != null) return _DetailScaffold(duty: item!);
    return FutureBuilder<PharmacyDutyItem?>(
      future: _loadFromMerchantPublic(pharmacyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final duty = snapshot.data;
        if (snapshot.hasError || duty == null) {
          return const _NotFoundScaffold();
        }
        return _DetailScaffold(duty: duty);
      },
    );
  }
}

class _DetailScaffold extends ConsumerStatefulWidget {
  const _DetailScaffold({
    required this.duty,
  });

  final PharmacyDutyItem duty;

  @override
  ConsumerState<_DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends ConsumerState<_DetailScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(
        event: 'surface_viewed',
        parameters: {
          'surface': 'pharmacy_duty_detail',
          'zoneId': widget.duty.zoneId,
        },
      );
      ref.read(analyticsServiceProvider).track(
        event: 'pharmacy_duty_detail_opened',
        parameters: {
          'surface': 'pharmacy_duty_detail',
          'zoneId': widget.duty.zoneId,
          'merchantId': widget.duty.merchantId,
          'source': 'pharmacy_duty_detail',
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final duty = widget.duty;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BackButtonHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.errorFg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'GUARDIA',
                        style: AppTextStyles.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(duty.merchantName, style: AppTextStyles.headingMd),
                    const SizedBox(height: 4),
                    Text(duty.addressLine, style: AppTextStyles.bodyMd),
                    const Spacer(),
                    if (duty.canNavigate)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(analyticsServiceProvider).track(
                              event: 'pharmacy_duty_useful_action_clicked',
                              parameters: {
                                'surface': 'pharmacy_duty_detail',
                                'zoneId': duty.zoneId,
                                'merchantId': duty.merchantId,
                                'action_type': 'directions',
                                'distance_bucket': 'unknown',
                                'source': 'pharmacy_duty_detail',
                                'elapsed_time_bucket': ref
                                    .read(analyticsServiceProvider)
                                    .elapsedTimeBucketNow(),
                              },
                            );
                            await ref.read(analyticsServiceProvider).track(
                              event: 'useful_action_clicked',
                              parameters: {
                                'surface': 'pharmacy_duty_detail',
                                'zoneId': duty.zoneId,
                                'merchantId': duty.merchantId,
                                'action_type': 'directions',
                                'distance_bucket': 'unknown',
                                'source': 'pharmacy_duty_detail',
                                'elapsed_time_bucket': ref
                                    .read(analyticsServiceProvider)
                                    .elapsedTimeBucketNow(),
                              },
                            );
                            await _launchMaps(duty);
                          },
                          icon: const Icon(Icons.directions_outlined, size: 18),
                          label: const Text('Cómo llegar'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: AppColors.primary500,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (duty.canNavigate) const SizedBox(height: 10),
                    if (duty.canCall)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(analyticsServiceProvider).track(
                              event: 'pharmacy_duty_useful_action_clicked',
                              parameters: {
                                'surface': 'pharmacy_duty_detail',
                                'zoneId': duty.zoneId,
                                'merchantId': duty.merchantId,
                                'action_type': 'call',
                                'distance_bucket': 'unknown',
                                'source': 'pharmacy_duty_detail',
                                'elapsed_time_bucket': ref
                                    .read(analyticsServiceProvider)
                                    .elapsedTimeBucketNow(),
                              },
                            );
                            await ref.read(analyticsServiceProvider).track(
                              event: 'useful_action_clicked',
                              parameters: {
                                'surface': 'pharmacy_duty_detail',
                                'zoneId': duty.zoneId,
                                'merchantId': duty.merchantId,
                                'action_type': 'call',
                                'distance_bucket': 'unknown',
                                'source': 'pharmacy_duty_detail',
                                'elapsed_time_bucket': ref
                                    .read(analyticsServiceProvider)
                                    .elapsedTimeBucketNow(),
                              },
                            );
                            await _launchPhone(duty.phone!);
                          },
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Llamar'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackButtonHeader(),
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _BackButtonHeader(),
            Expanded(
              child: Center(
                child: Text('No se encontró información de la farmacia.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButtonHeader extends StatelessWidget {
  const _BackButtonHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}

Future<PharmacyDutyItem?> _loadFromMerchantPublic(String pharmacyId) async {
  final doc =
      await FirebaseFirestore.instance.doc('merchant_public/$pharmacyId').get();
  if (!doc.exists) return null;
  final data = doc.data();
  if (data == null) return null;

  final geo = _extractGeo(data);
  return PharmacyDutyItem(
    dutyId: '',
    merchantId: pharmacyId,
    merchantName: (data['name'] as String?)?.trim() ?? '',
    addressLine: (data['addressLine'] as String?)?.trim() ?? '',
    phone: (data['phone'] as String?)?.trim(),
    latitude: geo?.$1,
    longitude: geo?.$2,
    zoneId: (data['zoneId'] as String?)?.trim() ?? '',
    dutyDate: '',
    isOnDuty: false,
    isOpenNow: data['isOpenNow'] == true,
    is24Hours: data['is24Hours'] == true,
    verificationStatus: (data['verificationStatus'] as String?) ?? 'unverified',
    sortBoost: (data['sortBoost'] as num?)?.toInt() ?? 0,
  );
}

(double, double)? _extractGeo(Map<String, dynamic> data) {
  final rawGeo = data['geo'];
  if (rawGeo is GeoPoint) return (rawGeo.latitude, rawGeo.longitude);
  if (rawGeo is Map<String, dynamic>) {
    final lat = (rawGeo['lat'] as num?)?.toDouble();
    final lng = (rawGeo['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) return (lat, lng);
  }
  final lat = (data['lat'] as num?)?.toDouble();
  final lng = (data['lng'] as num?)?.toDouble();
  if (lat != null && lng != null) return (lat, lng);
  return null;
}

Future<void> _launchPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _launchMaps(PharmacyDutyItem item) async {
  Uri uri;
  if (item.latitude != null && item.longitude != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${item.latitude},${item.longitude}',
    );
  } else {
    final encodedAddress = Uri.encodeComponent(item.addressLine);
    uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
  }
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
