import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/import_data_repository.dart';
import '../models/import_batch_ui.dart';

/// Pantalla de historial completo de batches de importación.
/// Incluye filtros por tipo, fuente y estado, tabla paginada y cards de análisis.
class ImportBatchHistoryScreen extends StatefulWidget {
  const ImportBatchHistoryScreen({super.key});

  @override
  State<ImportBatchHistoryScreen> createState() =>
      _ImportBatchHistoryScreenState();
}

class _ImportBatchHistoryScreenState extends State<ImportBatchHistoryScreen> {
  final _repository = ImportDataRepository();
  String? _typeFilter;
  String? _statusFilter;
  int _currentPage = 1;
  static const _pageSize = 10;

  List<ImportBatchUi> _filtered(List<ImportBatchUi> batches) {
    return batches.where((b) {
      if (_typeFilter != null && b.importType.label != _typeFilter)
        return false;
      if (_statusFilter != null && b.statusLabel != _statusFilter) return false;
      return true;
    }).toList();
  }

  List<ImportBatchUi> _paginated(List<ImportBatchUi> batches) {
    final filtered = _filtered(batches);
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int _totalPages(List<ImportBatchUi> batches) =>
      (_filtered(batches).length / _pageSize).ceil().clamp(1, 999);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: StreamBuilder<List<ImportBatchUi>>(
        stream: _repository.watchBatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudo cargar el historial.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final batches = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildFiltersBar(batches),
                const SizedBox(height: 16),
                _buildTable(context, batches),
                const SizedBox(height: 16),
                _buildPaginationRow(batches),
                const SizedBox(height: 24),
                _buildAnalysisCards(batches),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/imports'),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                const Icon(Icons.arrow_back,
                    size: 16, color: AppColors.neutral500),
                const SizedBox(width: 6),
                Text('Import Management',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.neutral500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text('/', style: TextStyle(color: AppColors.neutral300)),
        const SizedBox(width: 12),
        Text('Batch History', style: AppTextStyles.headingMd),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => context.go('/imports/new'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Import'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary500,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            textStyle: AppTextStyles.labelSm,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar(List<ImportBatchUi> batches) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: AppColors.neutral400),
          const SizedBox(width: 8),
          Text('Filter by:',
              style:
                  AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500)),
          const SizedBox(width: 16),
          _FilterChip(
            label: 'Type',
            value: _typeFilter,
            options: ImportType.values.map((t) => t.label).toList(),
            onChanged: (v) => setState(() {
              _typeFilter = v;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Status',
            value: _statusFilter,
            options: const [
              'Completado',
              'En proceso',
              'Fallido',
              'Escondido',
              'Revertido'
            ],
            onChanged: (v) => setState(() {
              _statusFilter = v;
              _currentPage = 1;
            }),
          ),
          const Spacer(),
          if (_typeFilter != null || _statusFilter != null)
            TextButton(
              onPressed: () => setState(() {
                _typeFilter = null;
                _statusFilter = null;
                _currentPage = 1;
              }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.neutral500,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: AppTextStyles.labelSm,
              ),
              child: const Text('Clear filters'),
            ),
          Text(
            '${_filtered(batches).length} batches',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<ImportBatchUi> batches) {
    final paginated = _paginated(batches);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          // Encabezados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              children: [
                _headerCell('BATCH ID', flex: 1),
                _headerCell('IMPORT TYPE', flex: 2),
                _headerCell('SOURCE / FILE', flex: 3),
                _headerCell('STATUS', flex: 2),
                _headerCell('METRICS', flex: 2),
                _headerCell('CREATED BY', flex: 2),
                _headerCell('DATE', flex: 2),
                _headerCell('', flex: 1),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          if (paginated.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No batches match the selected filters.',
                    style:
                        TextStyle(color: AppColors.neutral400, fontSize: 13)),
              ),
            )
          else
            ...paginated.map((batch) => _HistoryTableRow(
                  batch: batch,
                  onTap: () => context.go('/imports/${batch.id}'),
                )),
        ],
      ),
    );
  }

  Widget _buildPaginationRow(List<ImportBatchUi> batches) {
    final filteredCount = _filtered(batches).length;
    final totalPages = _totalPages(batches);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          style: IconButton.styleFrom(foregroundColor: AppColors.neutral600),
        ),
        ...List.generate(totalPages.clamp(1, 5), (i) {
          final page = i + 1;
          final isActive = page == _currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() => _currentPage = page),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary500 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.neutral600,
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          style: IconButton.styleFrom(foregroundColor: AppColors.neutral600),
        ),
        const SizedBox(width: 16),
        Text(
          'Page $_currentPage of $totalPages · $filteredCount total',
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
        ),
      ],
    );
  }

  Widget _buildAnalysisCards(List<ImportBatchUi> batches) {
    if (batches.isEmpty) {
      return const SizedBox.shrink();
    }
    final completed =
        batches.where((b) => b.status == ImportBatchStatus.completed).length;
    final failed =
        batches.where((b) => b.status == ImportBatchStatus.failed).length;
    final totalRows = batches.fold<int>(0, (sum, b) => sum + b.processedCount);
    final totalConflicts =
        batches.fold<int>(0, (sum, b) => sum + b.pendingReviewCount);

    return Row(
      children: [
        _AnalysisCard(
          title: 'Completion Rate',
          value: '${(completed / batches.length * 100).toStringAsFixed(0)}%',
          subtitle: '$completed completed / ${batches.length} total',
          color: AppColors.successFg,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(width: 16),
        _AnalysisCard(
          title: 'Total Rows Processed',
          value: NumberFormat.decimalPattern().format(totalRows),
          subtitle: 'Across all batches',
          color: AppColors.primary500,
          icon: Icons.table_rows_outlined,
        ),
        const SizedBox(width: 16),
        _AnalysisCard(
          title: 'Conflict Backlog',
          value: '$totalConflicts',
          subtitle: 'Rows pending manual review',
          color: AppColors.warningFg,
          icon: Icons.merge_type_outlined,
        ),
        const SizedBox(width: 16),
        _AnalysisCard(
          title: 'Failed Batches',
          value: '$failed',
          subtitle: 'Require attention or retry',
          color: AppColors.errorFg,
          icon: Icons.error_outline,
        ),
      ],
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral400,
            letterSpacing: 0.8),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  final String label;
  final String? value;
  final List<String> options;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(
            value: null, child: Text('All', style: AppTextStyles.bodySm)),
        ...options.map((o) => PopupMenuItem(
            value: o, child: Text(o, style: AppTextStyles.bodySm))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary500.withValues(alpha: 0.08)
              : AppColors.neutral50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  value != null ? AppColors.primary500 : AppColors.neutral200),
        ),
        child: Row(
          children: [
            Text(
              value ?? label,
              style: AppTextStyles.labelSm.copyWith(
                fontSize: 12,
                color:
                    value != null ? AppColors.primary500 : AppColors.neutral600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more,
                size: 14,
                color: value != null
                    ? AppColors.primary500
                    : AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}

class _HistoryTableRow extends StatefulWidget {
  const _HistoryTableRow({required this.batch, required this.onTap});
  final ImportBatchUi batch;
  final VoidCallback onTap;

  @override
  State<_HistoryTableRow> createState() => _HistoryTableRowState();
}

class _HistoryTableRowState extends State<_HistoryTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? AppColors.neutral50 : Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Batch ID
                    Expanded(
                      flex: 1,
                      child: Text('#${b.batchNumber}',
                          style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.primary500, fontSize: 12)),
                    ),
                    // Tipo
                    Expanded(
                      flex: 2,
                      child: Text(b.importType.label,
                          style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
                    ),
                    // Fuente / archivo
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.zone,
                              style:
                                  AppTextStyles.bodySm.copyWith(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          if (b.fileName != null)
                            Text(b.fileName!,
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.neutral400),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Estado
                    Expanded(flex: 2, child: _StatusBadge(status: b.status)),
                    // Métricas
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b.processedCount} rows',
                              style:
                                  AppTextStyles.bodyXs.copyWith(fontSize: 11)),
                          Text(
                              '${b.createdCount} created · ${b.errorCount} errors',
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.neutral400)),
                        ],
                      ),
                    ),
                    // Creado por
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.createdBy,
                              style:
                                  AppTextStyles.bodySm.copyWith(fontSize: 12)),
                          if (b.actorRole != null)
                            Text(b.actorRole!,
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.neutral400)),
                        ],
                      ),
                    ),
                    // Fecha
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd MMM yyyy\nHH:mm', 'es')
                            .format(b.createdAt),
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.neutral500),
                      ),
                    ),
                    // Acción
                    Expanded(
                      flex: 1,
                      child: Tooltip(
                        message: 'Ver detalle',
                        child: InkWell(
                          onTap: widget.onTap,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.open_in_new,
                                size: 14, color: AppColors.neutral400),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.neutral100),
            ],
          ),
        ),
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
      ImportBatchStatus.completed => (
          AppColors.successFg,
          AppColors.successFg.withValues(alpha: 0.1),
          'Completed'
        ),
      ImportBatchStatus.running => (
          AppColors.primary500,
          AppColors.primary500.withValues(alpha: 0.1),
          'Running'
        ),
      ImportBatchStatus.failed => (
          AppColors.errorFg,
          AppColors.errorFg.withValues(alpha: 0.1),
          'Failed'
        ),
      ImportBatchStatus.hidden => (
          AppColors.neutral500,
          AppColors.neutral200,
          'Staged'
        ),
      ImportBatchStatus.rolledBack => (
          AppColors.warningFg,
          AppColors.warningFg.withValues(alpha: 0.1),
          'Rolled Back'
        ),
      ImportBatchStatus.validated => (
          AppColors.secondary500,
          AppColors.secondary500.withValues(alpha: 0.1),
          'Validated'
        ),
      ImportBatchStatus.partial => (
          AppColors.warningFg,
          AppColors.warningFg.withValues(alpha: 0.1),
          'Partial'
        ),
      ImportBatchStatus.draft => (
          AppColors.neutral500,
          AppColors.neutral100,
          'Queued'
        ),
      ImportBatchStatus.archived => (
          AppColors.neutral400,
          AppColors.neutral100,
          'Archived'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.color,
      required this.icon});
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.neutral500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: AppTextStyles.headingSm.copyWith(fontSize: 18)),
                  Text(subtitle,
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.neutral400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
