import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OwnerPharmacyDutiesBulkUploadScreen extends StatelessWidget {
  const OwnerPharmacyDutiesBulkUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Carga masiva de turnos',
          style: AppTextStyles.headingSm,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 12),
          _buildFlowCard(context),
          const SizedBox(height: 12),
          _buildTemplateCard(context),
          const SizedBox(height: 12),
          _buildRulesCard(),
          const SizedBox(height: 12),
          _buildUploadCard(context),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.ownerPharmacyDuties),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Ir al calendario de turnos'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: AppColors.neutral300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF2D7A46)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Importá múltiples turnos en un solo archivo',
            style: AppTextStyles.headingMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Subí turnos de tu farmacia y de farmacias cercanas de tu red con validación por fila.',
            style: AppTextStyles.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(BuildContext context) {
    return _SectionCard(
      title: 'Flujo de carga',
      child: Column(
        children: [
          const _StepRow(
              number: 1, text: 'Descargá la plantilla Excel oficial.'),
          const SizedBox(height: 8),
          const _StepRow(number: 2, text: 'Completá cada fila con un turno.'),
          const SizedBox(height: 8),
          const _StepRow(
              number: 3, text: 'Subí el archivo para validar e importar.'),
          const SizedBox(height: 8),
          const _StepRow(
              number: 4, text: 'Revisá el resultado y corregí rechazos.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showPendingFeedback(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar plantilla'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context) {
    return _SectionCard(
      title: 'Columnas requeridas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _columnChip('fecha'),
          _columnChip('hora_desde'),
          _columnChip('hora_hasta'),
          _columnChip('farmacia_origen_id'),
          _columnChip('farmacia_turno_id'),
          _columnChip('tipo_turno'),
          _columnChip('observaciones'),
          const SizedBox(height: 10),
          Text(
            'Formato recomendado: fecha YYYY-MM-DD, horas HH:mm en zona local.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _showPendingFeedback(context),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Ver ejemplo de archivo'),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return _SectionCard(
      title: 'Validaciones automáticas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ruleItem('La farmacia destino debe ser propia o parte de la red.'),
          _ruleItem(
              'No se permiten turnos superpuestos para la misma farmacia.'),
          _ruleItem('Se controla formato y obligatoriedad de cada columna.'),
          _ruleItem('Cada rechazo devuelve motivo y número de fila.'),
        ],
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context) {
    return _SectionCard(
      title: 'Subir archivo',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Text(
              'Soporta .xlsx (hasta 5.000 filas por archivo).',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _showPendingFeedback(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Seleccionar archivo y validar'),
          ),
        ],
      ),
    );
  }

  Widget _columnChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(color: AppColors.primary700),
        ),
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySm),
          ),
        ],
      ),
    );
  }

  void _showPendingFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Carga masiva en habilitación. Se activa con backend de importación.',
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.primary700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTextStyles.bodySm),
        ),
      ],
    );
  }
}
