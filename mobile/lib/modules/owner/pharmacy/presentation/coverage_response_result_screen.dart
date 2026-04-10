import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CoverageResponseResultScreen extends StatelessWidget {
  const CoverageResponseResultScreen({
    super.key,
    required this.status,
    required this.action,
  });

  final String status;
  final String action;

  @override
  Widget build(BuildContext context) {
    final isAccepted = action == 'accept' && status == 'accepted';
    final isCoveredByAnother = action == 'accept' && !isAccepted;
    if (isAccepted) return _CoverageConfirmedView();
    if (isCoveredByAnother) return _AlreadyCoveredView();
    return _RejectedView();
  }
}

class _CoverageConfirmedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('Duty Reassignment', style: AppTextStyles.headingSm),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.secondary500,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ahora sos farmacia de turno',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingLg.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 52 / 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'La reasignación ha sido confirmada exitosamente en el sistema central.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.neutral700),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ESTADO DE TURNO',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.secondary500,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF99EFE5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'CONFIRMADO',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: const Color(0xFF006A63),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Activo ahora',
                        style: AppTextStyles.headingMd.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child:
                                _timeBox(label: 'INICIO', value: 'Hoy, 20:00'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                _timeBox(label: 'FIN', value: 'Mañana, 08:00'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_pharmacy,
                              color: AppColors.primary500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Farmacia Central Norte',
                                style: AppTextStyles.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'ID de Operación: #RX-9920',
                                style: AppTextStyles.bodySm,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.go(AppRoutes.ownerPharmacyDutyPublicStatus),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en el mapa público'),
                ),
                TextButton(
                  onPressed: () =>
                      context.go(AppRoutes.ownerPharmacyDutyUpcoming),
                  child: const Text('Volver al Dashboard'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style:
                AppTextStyles.headingSm.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AlreadyCoveredView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('Duty Reassignment', style: AppTextStyles.headingSm),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.primary500),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDECEA)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            height: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_paused,
                    size: 40,
                    color: AppColors.neutral500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ESTADO: FINALIZADO',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral700,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ya fue cubierto por otra farmacia',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingLg.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La guardia ya tiene cobertura asignada. Gracias por tu predisposición.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metaInfo(
                  icon: Icons.update,
                  label: 'ACTUALIZADO',
                  value: 'Hace 2 min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaInfo(
                  icon: Icons.verified_user,
                  label: 'CONFIRMACIÓN',
                  value: 'Sistema Central',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.ownerPharmacyDutyUpcoming),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              child: const Text('Volver'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ID Transacción: 772-OP-91',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _metaInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.neutral500),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RejectedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F7),
        elevation: 0,
        title: const Text('Resultado', style: AppTextStyles.headingSm),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.neutral700, size: 42),
              const SizedBox(height: 12),
              Text(
                'Invitación rechazada',
                style: AppTextStyles.headingSm
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu respuesta fue registrada.',
                style:
                    AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () =>
                    context.go(AppRoutes.ownerPharmacyDutyUpcoming),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    const step = 48.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
