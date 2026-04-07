import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MerchantDetailSkeleton extends StatelessWidget {
  const MerchantDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('merchant_detail_loading_state'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBlock(height: 250, width: double.infinity, radius: 18),
          SizedBox(height: 16),
          _SkeletonBlock(height: 16, width: 120),
          SizedBox(height: 10),
          _SkeletonBlock(height: 24, width: 280),
          SizedBox(height: 8),
          _SkeletonBlock(height: 14, width: 220),
          SizedBox(height: 22),
          _SkeletonBlock(height: 52, width: double.infinity, radius: 14),
          SizedBox(height: 26),
          _SkeletonBlock(height: 18, width: 160),
          SizedBox(height: 10),
          _SkeletonBlock(height: 130, width: double.infinity, radius: 16),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _SkeletonBlock(height: 170, width: 100, radius: 16)),
              SizedBox(width: 10),
              Expanded(
                  child: _SkeletonBlock(height: 170, width: 100, radius: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    required this.width,
    this.radius = 10,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
