import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final duty = item;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: context.pop,
              icon: const Icon(Icons.arrow_back),
            ),
            if (duty == null)
              const Expanded(
                child: Center(
                  child: Text('No se encontró información de la farmacia.'),
                ),
              )
            else
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
                            onPressed: () => _launchMaps(duty),
                            icon:
                                const Icon(Icons.directions_outlined, size: 18),
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
                            onPressed: () => _launchPhone(duty.phone!),
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

Future<void> _launchPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _launchMaps(PharmacyDutyItem item) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${item.latitude},${item.longitude}',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
