import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PublicDutyStatusScreen extends ConsumerStatefulWidget {
  const PublicDutyStatusScreen({super.key});

  @override
  ConsumerState<PublicDutyStatusScreen> createState() =>
      _PublicDutyStatusScreenState();
}

class _PublicDutyStatusScreenState
    extends ConsumerState<PublicDutyStatusScreen> {
  bool _loading = true;
  String _statusFilter = 'close_to_me';
  List<_PublicDutyItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('Duty Reassignment', style: AppTextStyles.headingSm),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.primary500),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or neighborhood...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Close to me', 'close_to_me'),
                    _chip('Open Now', 'open_now'),
                    _chip('24 Hours', 'always_open'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Active Pharmacies',
                      style: AppTextStyles.headingMd.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_items.length} results',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._items.map(_dutyCard),
                const SizedBox(height: 12),
                _mapCard(),
              ],
            ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
      labelStyle: AppTextStyles.bodyXs.copyWith(
        color: selected ? Colors.white : AppColors.neutral700,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary500,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _dutyCard(_PublicDutyItem item) {
    final statusText = item.publicStatusLabel == 'guardia_confirmada'
        ? 'GUARDIA CONFIRMADA'
        : item.publicStatusLabel == 'cambio_operativo_en_curso'
            ? 'CAMBIO OPERATIVO'
            : 'GUARDIA EN VERIFICACIÓN';
    final statusColor = item.publicStatusLabel == 'guardia_confirmada'
        ? AppColors.secondary500
        : item.publicStatusLabel == 'cambio_operativo_en_curso'
            ? AppColors.warningFg
            : AppColors.primary500;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              statusText,
              style: AppTextStyles.bodyXs.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.headingSm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.address, style: AppTextStyles.bodySm),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.near_me,
                        size: 14, color: AppColors.secondary500),
                    const SizedBox(width: 2),
                    Text(
                      '${item.distanceKm.toStringAsFixed(1)} km',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.secondary500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(
                          AppRoutes.commerceDetailPath(item.merchantId),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Get Directions'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.neutral100,
                      ),
                      icon:
                          const Icon(Icons.phone, color: AppColors.primary500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A8D97), Color(0xFF236D7B)],
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.map_outlined, color: Colors.white, size: 44),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'INTERACTIVE VIEW\nMap Overview',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                  ),
                  icon: const Icon(Icons.fullscreen, size: 16),
                  label: const Text('Expand Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('merchant_public')
          .where('categoryId', isEqualTo: 'pharmacy')
          .where('visibilityStatus', isEqualTo: 'visible')
          .where('hasPharmacyDutyToday', isEqualTo: true)
          .limit(8)
          .get();
      final loaded = snap.docs
          .map((doc) => _PublicDutyItem.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = loaded;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _PublicDutyItem {
  const _PublicDutyItem({
    required this.merchantId,
    required this.name,
    required this.address,
    required this.publicStatusLabel,
    required this.distanceKm,
  });

  final String merchantId;
  final String name;
  final String address;
  final String publicStatusLabel;
  final double distanceKm;

  factory _PublicDutyItem.fromFirestore(String id, Map<String, dynamic> data) {
    return _PublicDutyItem(
      merchantId: id,
      name: (data['name'] as String?)?.trim() ?? 'Farmacia',
      address: (data['address'] as String?)?.trim() ??
          (data['addressLine'] as String?)?.trim() ??
          'Dirección no disponible',
      publicStatusLabel: (data['publicStatusLabel'] as String?)?.trim() ??
          'guardia_en_verificacion',
      distanceKm: ((data['distanceKm'] as num?)?.toDouble() ?? 0) <= 0
          ? 0.4 + (id.hashCode.abs() % 80) / 10
          : (data['distanceKm'] as num).toDouble(),
    );
  }
}
