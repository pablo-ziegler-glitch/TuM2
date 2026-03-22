import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// DETAIL-01 — Ficha pública de comercio placeholder.
/// Accesible desde cualquier stack. Se implementa en TuM2-0058.
class CommerceDetailPlaceholderScreen extends StatelessWidget {
  final String commerceId;

  const CommerceDetailPlaceholderScreen({
    super.key,
    required this.commerceId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(
          color: AppColors.neutral900,
          onPressed: () => context.pop(),
        ),
        title: Text('Comercio', style: AppTextStyles.headingSm),
        centerTitle: false,
      ),
      body: PlaceholderScreen(
        screenId: 'DETAIL-01',
        label: 'Ficha de comercio: $commerceId',
      ),
    );
  }
}
