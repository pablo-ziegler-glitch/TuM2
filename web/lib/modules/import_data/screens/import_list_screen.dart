import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Pantalla principal de importaciones — Import Overview Dashboard.
/// Muestra KPIs globales, tabla de batches recientes y línea de auditoría.
class ImportListScreen extends StatefulWidget {
  const ImportListScreen({super.key});

  @override
  State<ImportListScreen> createState() => _ImportListScreenState();
}

class _ImportListScreenState extends State<ImportListScreen> {
  String _activeFilter = 'All';
  static const _filters = ['All', 'Official Dataset', 'Master Catalog', 'Generic'];

  List<ImportBatchUi> get _filteredBatches {
    if (_activeFilter == 'All') return mockBatches;
    return mockBatches.where((b) {
      return switch (_activeFilter) {
        'Official Dataset' => b.importType == ImportType.officialDataset,
        'Master Catalog' => b.importType == ImportType.masterCatalog,
        'Generic' => b.importType == ImportType.genericInternal,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildKpiRow(),
            const SizedBox(height: 20),
            _buildQuickFilters(),
            const SizedBox(height: 24),
            if (mockBatches.isEmpty)
              _buildEmptyState(context)
            else ...[
              _buildBatchesPanel(context),
              const SizedBox(height: 24),
              _buildRecentAuditTrail(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import Management', style: AppTextStyles.headingMd),
            const SizedBox(height: 2),
            Text(
              'Manage dataset imports, field mappings and data quality',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => context.go('/imports/history'),
          icon: const Icon(Icons.history, size: 15),
          label: const Text('Batch History'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neutral700,
            side: const BorderSide(color: AppColors.neutral300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: AppTextStyles.labelSm,
          ),
        ),
        const SizedBox(width: 10),
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

  Widget _buildKpiRow() {
    final kpis = mockOverviewKpis;
    return Row(
      children: [
        _KpiCard(label: 'Total Imports', value: '${kpis.totalImports}', icon: Icons.upload_file_outlined, color: AppColors.primary500),
        const SizedBox(width: 12),
        _KpiCard(label: 'Success Rate', value: '${(kpis.successRate * 100).toStringAsFixed(1)}%', icon: Icons.check_circle_outline, color: AppColors.successFg),
        const SizedBox(width: 12),
        _KpiCard(label: 'Failed Batches', value: '${kpis.failedBatches}', icon: Icons.error_outline, color: AppColors.errorFg),
        const SizedBox(width: 12),
        _KpiCard(label: 'Rows Processed', value: NumberFormat.compact().format(kpis.rowsProcessed), icon: Icons.table_rows_outlined, color: AppColors.secondary500),
        const SizedBox(width: 12),
        _KpiCard(label: 'Pending Conflicts', value: '${kpis.pendingConflicts}', icon: Icons.merge_type_outlined, color: AppColors.warningFg),
        const SizedBox(width: 12),
        _KpiCard(label: 'Active Templates', value: '${kpis.activeTemplates}', icon: Icons.description_outlined, color: AppColors.neutral600),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Row(
      children: _filters.map((filter) {
        final isActive = _activeFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary500 : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive ? AppColors.primary500 : AppColors.neutral200,
                ),
              ),
              child: Text(
                filter,
                style: AppTextStyles.labelSm.copyWith(
                  color: isActive ? Colors.white : AppColors.neutral700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBatchesPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Text('Recent Batches', style: AppTextStyles.headingSm.copyWith(fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/imports/history'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                    padding: EdgeInsets.zero,
                    textStyle: AppTextStyles.labelSm,
                  ),
                  child: const Text('View all →'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          _TableHeader(),
          const Divider(height: 1, color: AppColors.neutral100),
          ..._filteredBatches.map((batch) => _BatchTableRow(
            batch: batch,
            onTap: () => context.go('/imports/${batch.id}'),
          )),
        ],
      ),
    );
  }

  Widget _buildRecentAuditTrail(BuildContext context) {
    final batch = mockBatches.first;
    if (batch.auditTrail.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recent Audit Trail', style: AppTextStyles.headingSm.copyWith(fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Batch #${batch.batchNumber}', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/imports/${batch.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  padding: EdgeInsets.zero,
                  textStyle: AppTextStyles.labelSm,
                ),
                child: const Text('View full audit →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...batch.auditTrail.take(4).map((event) => _AuditTrailRow(event: event)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_file_outlined, size: 32, color: AppColors.primary500),
            ),
            const SizedBox(height: 20),
            Text('No imports yet', style: AppTextStyles.headingSm),
            const SizedBox(height: 8),
            Text(
              'Start by importing an official dataset, master catalog or custom source.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/imports/new'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Import'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeatureCard(icon: Icons.source_outlined, title: 'Official Datasets', description: 'REPES, WiFi, municipal data'),
                const SizedBox(width: 16),
                _FeatureCard(icon: Icons.inventory_2_outlined, title: 'Master Catalog', description: 'Products with barcode + brand'),
                const SizedBox(width: 16),
                _FeatureCard(icon: Icons.tune_outlined, title: 'Smart Mapping', description: 'AI-assisted field detection'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.headingSm.copyWith(fontSize: 20, color: AppColors.neutral900)),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _headerCell('BATCH', flex: 1),
          _headerCell('TYPE', flex: 2),
          _headerCell('ZONE / SOURCE', flex: 2),
          _headerCell('METRICS', flex: 2),
          _headerCell('STATUS', flex: 2),
          _headerCell('DATE', flex: 2),
          _headerCell('', flex: 1),
        ],
      ),
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
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _BatchTableRow extends StatefulWidget {
  const _BatchTableRow({required this.batch, required this.onTap});
  final ImportBatchUi batch;
  final VoidCallback onTap;

  @override
  State<_BatchTableRow> createState() => _BatchTableRowState();
}

class _BatchTableRowState extends State<_BatchTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '#${widget.batch.batchNumber}',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.primary500, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.batch.importType.label, style: AppTextStyles.labelSm.copyWith(fontSize: 12)),
                          Text(widget.batch.datasetType.label, style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.batch.zone,
                        style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          _MetricChip(value: widget.batch.processedCount, color: AppColors.neutral600),
                          const SizedBox(width: 4),
                          _MetricChip(value: widget.batch.createdCount, color: AppColors.successFg),
                          const SizedBox(width: 4),
                          if (widget.batch.errorCount > 0)
                            _MetricChip(value: widget.batch.errorCount, color: AppColors.errorFg),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _StatusBadge(status: widget.batch.status),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd MMM yyyy · HH:mm', 'es').format(widget.batch.createdAt),
                        style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Tooltip(
                        message: 'Ver detalle',
                        child: InkWell(
                          onTap: widget.onTap,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.open_in_new, size: 14, color: AppColors.neutral400),
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.color});
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$value',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
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
      ImportBatchStatus.completed => (AppColors.successFg, AppColors.successFg.withValues(alpha: 0.1), 'Completed'),
      ImportBatchStatus.running => (AppColors.primary500, AppColors.primary500.withValues(alpha: 0.1), 'Running'),
      ImportBatchStatus.failed => (AppColors.errorFg, AppColors.errorFg.withValues(alpha: 0.1), 'Failed'),
      ImportBatchStatus.hidden => (AppColors.neutral500, AppColors.neutral200, 'Staged'),
      ImportBatchStatus.rolledBack => (AppColors.warningFg, AppColors.warningFg.withValues(alpha: 0.1), 'Rolled Back'),
      ImportBatchStatus.validated => (AppColors.secondary500, AppColors.secondary500.withValues(alpha: 0.1), 'Validated'),
      ImportBatchStatus.partial => (AppColors.warningFg, AppColors.warningFg.withValues(alpha: 0.1), 'Partial'),
      ImportBatchStatus.draft => (AppColors.neutral500, AppColors.neutral100, 'Draft'),
      ImportBatchStatus.archived => (AppColors.neutral400, AppColors.neutral100, 'Archived'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _AuditTrailRow extends StatelessWidget {
  const _AuditTrailRow({required this.event});
  final AuditTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: event.result
                  ? AppColors.successFg.withValues(alpha: 0.1)
                  : AppColors.errorFg.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.result ? Icons.check : Icons.close,
              size: 14,
              color: event.result ? AppColors.successFg : AppColors.errorFg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(event.label, style: AppTextStyles.labelSm.copyWith(fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('· ${event.actor}', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400)),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM · HH:mm', 'es').format(event.timestamp),
                      style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
                    ),
                  ],
                ),
                if (event.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(event.detail!, style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.primary500),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.labelMd.copyWith(fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(description, style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
