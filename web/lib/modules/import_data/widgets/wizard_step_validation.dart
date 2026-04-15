import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 5 del wizard — Validation & Preview.
/// Muestra KPIs de validación, tabs de filas por estado y recomendación de estrategia.
class WizardStepValidation extends StatefulWidget {
  const WizardStepValidation({super.key, required this.previewRows});

  final List<CsvPreviewRow> previewRows;

  @override
  State<WizardStepValidation> createState() => _WizardStepValidationState();
}

class _WizardStepValidationState extends State<WizardStepValidation>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _validCount =>
      widget.previewRows.where((r) => !r.hasError && !r.hasWarning).length;
  int get _warningCount =>
      widget.previewRows.where((r) => r.hasWarning && !r.hasError).length;
  int get _errorCount => widget.previewRows.where((r) => r.hasError).length;
  int get _total => widget.previewRows.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Validation & Preview', style: AppTextStyles.headingSm),
        const SizedBox(height: 4),
        Text(
          'Review validation results before confirming the import.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(height: 20),
        _buildKpiRow(),
        const SizedBox(height: 20),
        _buildTabBar(),
        const SizedBox(height: 1),
        _buildTabContent(),
        const SizedBox(height: 20),
        _buildStrategyRecommendation(),
      ],
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        _ValidationKpi(
          label: 'Total Rows',
          value: '$_total',
          icon: Icons.table_rows_outlined,
          color: AppColors.neutral600,
        ),
        const SizedBox(width: 12),
        _ValidationKpi(
          label: 'Valid',
          value: '$_validCount',
          icon: Icons.check_circle_outline,
          color: AppColors.successFg,
        ),
        const SizedBox(width: 12),
        _ValidationKpi(
          label: 'Warnings',
          value: '$_warningCount',
          icon: Icons.warning_amber_outlined,
          color: AppColors.warningFg,
        ),
        const SizedBox(width: 12),
        _ValidationKpi(
          label: 'Errors',
          value: '$_errorCount',
          icon: Icons.error_outline,
          color: AppColors.errorFg,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutral200)),
      ),
      child: TabBar(
        controller: _tabController,
        labelStyle: AppTextStyles.labelSm.copyWith(fontSize: 12),
        unselectedLabelStyle: AppTextStyles.bodySm.copyWith(fontSize: 12),
        labelColor: AppColors.primary500,
        unselectedLabelColor: AppColors.neutral500,
        indicatorColor: AppColors.primary500,
        indicatorWeight: 2,
        tabs: [
          Tab(text: 'SUMMARY ($_total)'),
          Tab(text: 'VALID ($_validCount)'),
          Tab(text: 'WARNINGS & ERRORS (${_warningCount + _errorCount})'),
          const Tab(text: 'DESTINATION IMPACT'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 280,
      child: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(rows: widget.previewRows),
          _RowsTab(
            rows: widget.previewRows
                .where((r) => !r.hasError && !r.hasWarning)
                .toList(),
            emptyLabel: 'No valid rows',
          ),
          _IssuesTab(
            rows: widget.previewRows
                .where((r) => r.hasError || r.hasWarning)
                .toList(),
          ),
          _DestinationImpactTab(
            validCount: _validCount,
            errorCount: _errorCount,
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyRecommendation() {
    final hasErrors = _errorCount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasErrors
            ? AppColors.warningFg.withValues(alpha: 0.06)
            : AppColors.successFg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasErrors
              ? AppColors.warningFg.withValues(alpha: 0.3)
              : AppColors.successFg.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasErrors
                ? Icons.tips_and_updates_outlined
                : Icons.check_circle_outline,
            size: 18,
            color: hasErrors ? AppColors.warningFg : AppColors.successFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasErrors
                      ? 'Data Strategy Recommendation'
                      : 'Ready to Import',
                  style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  hasErrors
                      ? '$_errorCount rows have errors and will be skipped. $_validCount valid rows and $_warningCount warning rows will be staged. You can review and resolve skipped rows after import via the Conflict Review panel.'
                      : 'All $_total rows passed validation. The import is ready to be confirmed and staged.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab views ─────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.rows});
  final List<CsvPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: _PreviewTable(rows: rows));
  }
}

class _RowsTab extends StatelessWidget {
  const _RowsTab({required this.rows, required this.emptyLabel});
  final List<CsvPreviewRow> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral400),
        ),
      );
    }
    return SingleChildScrollView(child: _PreviewTable(rows: rows));
  }
}

class _IssuesTab extends StatelessWidget {
  const _IssuesTab({required this.rows});
  final List<CsvPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.successFg,
            ),
            const SizedBox(width: 8),
            Text(
              'No issues found',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(children: rows.map((r) => _IssueRow(row: r)).toList()),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.row});
  final CsvPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final isError = row.hasError;
    final color = isError ? AppColors.errorFg : AppColors.warningFg;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.warning_amber_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: AppTextStyles.labelSm.copyWith(fontSize: 12),
                ),
                Text(
                  '${row.address} · Lon: ${row.longitude} · Lat: ${row.latitude}',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isError ? 'ERROR' : 'WARNING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary500,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle: AppTextStyles.labelSm.copyWith(fontSize: 11),
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _DestinationImpactTab extends StatelessWidget {
  const _DestinationImpactTab({
    required this.validCount,
    required this.errorCount,
  });
  final int validCount;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImpactRow(
            icon: Icons.storage_outlined,
            label: 'Records to be staged',
            value: '$validCount',
            color: AppColors.primary500,
          ),
          const SizedBox(height: 12),
          _ImpactRow(
            icon: Icons.block_outlined,
            label: 'Records to be skipped',
            value: '$errorCount',
            color: AppColors.errorFg,
          ),
          const SizedBox(height: 12),
          _ImpactRow(
            icon: Icons.visibility_off_outlined,
            label: 'Initial visibility',
            value: 'Hidden (staging)',
            color: AppColors.neutral500,
          ),
          const SizedBox(height: 12),
          _ImpactRow(
            icon: Icons.merge_type_outlined,
            label: 'Deduplication',
            value: 'Enabled · name + geohash',
            color: AppColors.secondary500,
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySm.copyWith(fontSize: 12),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelMd.copyWith(color: color, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Preview table ─────────────────────────────────────────────────────────────

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.rows});
  final List<CsvPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          color: AppColors.neutral50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: const [
              Expanded(flex: 3, child: _HeaderCell('NAME')),
              Expanded(flex: 2, child: _HeaderCell('LOCALITY')),
              Expanded(flex: 1, child: _HeaderCell('TYPE')),
              Expanded(flex: 3, child: _HeaderCell('ADDRESS')),
              Expanded(flex: 2, child: _HeaderCell('LON')),
              Expanded(flex: 2, child: _HeaderCell('LAT')),
              Expanded(flex: 1, child: _HeaderCell('')),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.neutral100),
        ...rows.map((row) {
          final isError = row.hasError;
          final isWarn = row.hasWarning;
          return Container(
            color: isError
                ? AppColors.errorFg.withValues(alpha: 0.04)
                : isWarn
                    ? AppColors.warningFg.withValues(alpha: 0.04)
                    : Colors.transparent,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.name,
                          style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.locality,
                          style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          row.typology,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.address,
                          style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.longitude,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: isError
                                ? AppColors.errorFg
                                : AppColors.neutral600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.latitude,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: isError
                            ? const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppColors.errorFg,
                              )
                            : isWarn
                                ? const Icon(
                                    Icons.warning_amber_outlined,
                                    size: 14,
                                    color: AppColors.warningFg,
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: AppColors.successFg,
                                  ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.neutral100),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.neutral400,
        letterSpacing: 0.7,
      ),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _ValidationKpi extends StatelessWidget {
  const _ValidationKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.headingSm.copyWith(fontSize: 18),
                ),
                Text(
                  label,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral500,
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
