import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// IMPORT-00 / IMPORT-01 — Lista de importaciones de datasets.
/// Muestra el estado vacío si no hay batches, o la tabla con paginación.
class ImportListScreen extends StatefulWidget {
  const ImportListScreen({super.key});

  @override
  State<ImportListScreen> createState() => _ImportListScreenState();
}

class _ImportListScreenState extends State<ImportListScreen> {
  final List<ImportBatchUi> _batches = mockBatches;
  int _currentPage = 0;
  static const _pageSize = 10;

  List<ImportBatchUi> get _pageBatches {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _batches.length);
    return _batches.sublist(start, end);
  }

  int get _totalPages => (_batches.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final isEmpty = _batches.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: isEmpty ? _EmptyState() : _ListContent(
          batches: _pageBatches,
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPageChanged: (p) => setState(() => _currentPage = p),
          onNewImport: () => context.go('/datasets/new'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/datasets/new'),
        backgroundColor: AppColors.primary500,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add New Commerce',
          style: AppTextStyles.labelMd.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono central
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add_circle_outline, size: 40, color: AppColors.neutral500),
            ),
            const SizedBox(height: 24),
            Text('Importaciones de datasets', style: AppTextStyles.headingMd),
            const SizedBox(height: 8),
            Text(
              'Cargá datos oficiales para pre-poblar el directorio y asegurarte que los ciudadanos encuentren información validada desde el primer día.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/datasets/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nueva importación'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            const SizedBox(height: 32),
            // Formatos soportados
            Text(
              'FORMATOS SOPORTADOS',
              style: AppTextStyles.labelSm.copyWith(
                letterSpacing: 1.0,
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FormatChip(icon: Icons.table_chart_outlined, label: 'CSV'),
                const SizedBox(width: 12),
                _FormatChip(icon: Icons.data_object_outlined, label: 'JSON'),
                const SizedBox(width: 12),
                _FormatChip(icon: Icons.api_outlined, label: 'API Endpoint'),
              ],
            ),
            const SizedBox(height: 40),
            // Feature cards
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.book_outlined,
                    iconColor: AppColors.primary500,
                    title: 'Guía de formatos',
                    description: 'Descargá nuestras plantillas oficiales para asegurar que tus datos se procesen sin errores.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.auto_fix_high_outlined,
                    iconColor: AppColors.secondary500,
                    title: 'Mapeo inteligente',
                    description: 'Nuestra IA intentará detectar automáticamente las columnas de dirección, nombre y categoría.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.history_outlined,
                    iconColor: AppColors.tertiary500,
                    title: 'Historial de carga',
                    description: 'Podés ver el estado de cada importación y descargar reportes de errores si algo falla.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.neutral600),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelSm),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 6),
          Text(description, style: AppTextStyles.bodyXs),
        ],
      ),
    );
  }
}

// ── Contenido con tabla ───────────────────────────────────────────────────────

class _ListContent extends StatelessWidget {
  const _ListContent({
    required this.batches,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onNewImport,
  });

  final List<ImportBatchUi> batches;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onNewImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Importaciones de datasets', style: AppTextStyles.headingLg),
                  const SizedBox(height: 4),
                  Text(
                    'Cargá datos oficiales para pre-poblar el directorio. Los registros importados quedan ocultos hasta que los revises.',
                    style: AppTextStyles.bodySm,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onNewImport,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+ Nueva importación'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Tabla principal
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral100),
            ),
            child: Column(
              children: [
                // Header de la tabla
                _TableHeader(),
                const Divider(height: 1, color: AppColors.neutral100),
                // Filas
                ...batches.map((b) => Column(
                  children: [
                    _BatchRow(batch: b),
                    const Divider(height: 1, color: AppColors.neutral100),
                  ],
                )),
                // Paginación
                _Pagination(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                  totalItems: mockBatches.length,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Footer con métricas globales
        _MetricsFooter(),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.neutral500,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 160, child: Text('FECHA', style: style)),
          const SizedBox(width: 180, child: Text('TIPO DE DATASET', style: style)),
          const SizedBox(width: 200, child: Text('ZONA', style: style)),
          Expanded(child: const Text('METRICS', style: style)),
          const SizedBox(width: 120, child: Text('ESTADO', style: style)),
          const SizedBox(width: 160, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy\nHH:mm').format(batch.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Fecha
          SizedBox(
            width: 160,
            child: Text(dateStr, style: AppTextStyles.bodyXs),
          ),
          // Tipo de dataset
          SizedBox(
            width: 180,
            child: Text(batch.datasetType.label, style: AppTextStyles.bodySm),
          ),
          // Zona
          SizedBox(
            width: 200,
            child: Text(batch.zone, style: AppTextStyles.bodyXs, maxLines: 2),
          ),
          // Métricas
          Expanded(
            child: Row(
              children: [
                _MetricChip(value: batch.processedCount, color: AppColors.neutral700),
                const SizedBox(width: 6),
                _MetricChip(value: batch.pendingReviewCount, color: AppColors.tertiary500),
                const SizedBox(width: 6),
                _MetricChip(value: batch.errorCount, color: AppColors.errorFg),
              ],
            ),
          ),
          // Estado
          SizedBox(
            width: 120,
            child: _StatusBadge(status: batch.status),
          ),
          // Acciones
          SizedBox(
            width: 160,
            child: _BatchActions(batch: batch),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.color});
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ImportBatchStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      ImportBatchStatus.completed => (AppColors.successFg, AppColors.successBg, '● Completado'),
      ImportBatchStatus.running   => (AppColors.primary500, AppColors.primary50, '● En proceso'),
      ImportBatchStatus.failed    => (AppColors.errorFg, AppColors.errorBg, '● Fallido'),
      ImportBatchStatus.hidden    => (AppColors.neutral600, AppColors.neutral100, '● Escondido'),
      ImportBatchStatus.rolledBack => (AppColors.neutral600, AppColors.neutral100, '● Revertido'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _BatchActions extends StatelessWidget {
  const _BatchActions({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    final canView = batch.status == ImportBatchStatus.completed || batch.status == ImportBatchStatus.failed;
    return Row(
      children: [
        TextButton(
          onPressed: canView ? () => context.go('/datasets/${batch.id}') : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.primary500,
          ),
          child: Text(
            batch.status == ImportBatchStatus.completed ? 'VER RESULTADO' : 'VER ERROR',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.totalItems,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Mostrando 4 de $totalItems importaciones',
            style: AppTextStyles.bodyXs,
          ),
          const Spacer(),
          ...List.generate(totalPages > 3 ? 3 : totalPages, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PageBtn(page: i, current: currentPage, onTap: onPageChanged),
            );
          }),
          if (totalPages > 3) ...[
            Text('...', style: AppTextStyles.bodyXs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PageBtn(page: totalPages - 1, current: currentPage, onTap: onPageChanged),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({required this.page, required this.current, required this.onTap});
  final int page;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = page == current;
    return GestureDetector(
      onTap: () => onTap(page),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? null : Border.all(color: AppColors.neutral200),
        ),
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.white : AppColors.neutral700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer de métricas globales ───────────────────────────────────────────────

class _MetricsFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Totales calculados del mock
    final totalRegistros = mockBatches.fold(0, (s, b) => s + b.processedCount);
    final pendientes = mockBatches.fold(0, (s, b) => s + b.pendingReviewCount);
    final completed = mockBatches.where((b) => b.status == ImportBatchStatus.completed).length;
    final health = mockBatches.isEmpty ? 0.0 : (completed / mockBatches.length) * 100;

    return Row(
      children: [
        Expanded(child: _KpiCard(
          label: 'TOTAL REGISTROS',
          value: _fmt(totalRegistros),
          subtitle: '+1.2k esta mes',
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label: 'PENDIENTES DE REVISIÓN',
          value: _fmt(pendientes),
          subtitle: 'Acción requerida',
          valueColor: AppColors.tertiary500,
        )),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(
          label: 'SALUD DE INTEGRACIÓN',
          value: '${health.toStringAsFixed(1)}%',
          subtitle: 'Sincronizado',
          valueColor: AppColors.successFg,
        )),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });
  final String label;
  final String value;
  final String subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSm.copyWith(letterSpacing: 0.8, color: AppColors.neutral500)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headingMd.copyWith(color: valueColor ?? AppColors.neutral900),
          ),
          Text(subtitle, style: AppTextStyles.bodyXs),
        ],
      ),
    );
  }
}
