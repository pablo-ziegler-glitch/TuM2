import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/admin_semantic_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/import_data_repository.dart';
import '../models/import_batch_ui.dart';
import '../widgets/revert_confirm_dialog.dart';

/// Pantalla de detalle de un batch — Batch Detail Audit View.
/// Muestra: Processing Timeline, File Intelligence, Actor Context,
/// Conflict Logic Summary y tabla de Validation Issues.
class ImportResultScreen extends StatefulWidget {
  const ImportResultScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<ImportResultScreen> createState() => _ImportResultScreenState();
}

class _ImportResultScreenState extends State<ImportResultScreen>
    with SingleTickerProviderStateMixin {
  final _repository = ImportDataRepository();
  late final TabController _tabController;
  bool _isPublishing = false;
  bool _isReverting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: StreamBuilder<ImportBatchUi?>(
        stream: _repository.watchBatch(widget.batchId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudo cargar el batch.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final batch = snapshot.data;
          if (batch == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off_outlined,
                    size: 40,
                    color: AppColors.neutral400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Importacion no encontrada',
                    style: AppTextStyles.headingSm,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID de batch: ${widget.batchId}',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumb(context, batch),
                const SizedBox(height: 20),
                _buildHeaderRow(context, batch),
                const SizedBox(height: 20),
                _buildKpiRow(batch),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProcessingTimeline(batch),
                          const SizedBox(height: 20),
                          _buildValidationIssuesPanel(batch),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          _buildFileIntelligenceCard(batch),
                          const SizedBox(height: 16),
                          _buildActorContextCard(batch),
                          const SizedBox(height: 16),
                          _buildConflictLogicCard(batch),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context, ImportBatchUi batch) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/imports'),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_back,
                  size: 15,
                  color: AppColors.neutral500,
                ),
                const SizedBox(width: 5),
                Text(
                  'Importaciones',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('/', style: TextStyle(color: AppColors.neutral300)),
        const SizedBox(width: 8),
        Text(
          'Batch #${batch.batchNumber}',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context, ImportBatchUi batch) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Batch #${batch.batchNumber}',
                  style: AppTextStyles.headingMd,
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: batch.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${batch.importType.label} · ${batch.datasetType.label} · ${batch.zone}',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
            ),
          ],
        ),
        const Spacer(),
        // Acciones
        if (batch.status == ImportBatchStatus.completed ||
            batch.status == ImportBatchStatus.hidden)
          OutlinedButton.icon(
            onPressed: _isReverting
                ? null
                : () => _showRevertDialog(context, batch),
            icon: const Icon(Icons.undo, size: 15),
            label: Text(_isReverting ? 'Revirtiendo...' : 'Revertir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorFg,
              side: BorderSide(color: AppColors.errorFg.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: AppTextStyles.labelSm,
            ),
          ),
        const SizedBox(width: 10),
        if (batch.status == ImportBatchStatus.hidden)
          FilledButton.icon(
            onPressed: _isPublishing ? null : () => _publishBatch(batch),
            icon: const Icon(Icons.visibility, size: 15),
            label: Text(_isPublishing ? 'Publicando...' : 'Publicar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: AppTextStyles.labelSm,
            ),
          ),
      ],
    );
  }

  Widget _buildKpiRow(ImportBatchUi batch) {
    return Row(
      children: [
        _KpiCard(
          label: 'Filas totales',
          value: '${batch.processedCount}',
          icon: Icons.table_rows_outlined,
          color: AppColors.neutral600,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Creadas',
          value: '${batch.createdCount}',
          icon: Icons.add_circle_outline,
          color: AppColors.successFg,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Duplicadas',
          value: '${batch.duplicatedCount}',
          icon: Icons.copy_outlined,
          color: AppColors.secondary500,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Errores',
          value: '${batch.errorCount}',
          icon: Icons.error_outline,
          color: AppColors.errorFg,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Pendiente de revision',
          value: '${batch.pendingReviewCount}',
          icon: Icons.pending_outlined,
          color: AppColors.warningFg,
        ),
        const SizedBox(width: 12),
        _KpiCard(
          label: 'Tasa de exito',
          value: '${(batch.successRate * 100).toStringAsFixed(1)}%',
          icon: Icons.trending_up_outlined,
          color: batch.successRate >= 0.9
              ? AppColors.successFg
              : AppColors.warningFg,
        ),
      ],
    );
  }

  Widget _buildProcessingTimeline(ImportBatchUi batch) {
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
          Text(
            'Linea de tiempo de procesamiento',
            style: AppTextStyles.headingSm.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (batch.auditTrail.isEmpty)
            Text(
              'No hay eventos disponibles',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral400),
            )
          else
            ...batch.auditTrail.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              final isLast = i == batch.auditTrail.length - 1;
              return _TimelineRow(event: event, isLast: isLast);
            }),
        ],
      ),
    );
  }

  Widget _buildValidationIssuesPanel(ImportBatchUi batch) {
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Problemas de validacion',
                  style: AppTextStyles.headingSm.copyWith(fontSize: 14),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorFg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${batch.errors.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          if (batch.errors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.successFg,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No hay problemas de validacion',
                    style: TextStyle(color: AppColors.successFg, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Encabezados
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  child: Row(
                    children: const [
                      _HeaderCell('FILA', flex: 1),
                      _HeaderCell('ESTABLECIMIENTO', flex: 3),
                      _HeaderCell('PROBLEMA', flex: 4),
                      _HeaderCell('SEVERIDAD', flex: 2),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.neutral100),
                ...batch.errors.map((e) => _IssueTableRow(error: e)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFileIntelligenceCard(ImportBatchUi batch) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 8),
              Text(
                'Informacion del archivo',
                style: AppTextStyles.labelMd.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Nombre', value: batch.fileName ?? '—'),
          _InfoRow(label: 'Tamano', value: batch.fileSize ?? '—'),
          if (batch.fileHash != null)
            _InfoRow(
              label: 'SHA-256',
              value: '${batch.fileHash!.substring(0, 12)}…',
            ),
          _InfoRow(label: 'Template', value: batch.templateName ?? '—'),
          _InfoRow(label: 'Tipo', value: batch.importType.label),
          if (batch.finishedAt != null)
            _InfoRow(
              label: 'Duracion',
              value:
                  '${batch.finishedAt!.difference(batch.createdAt).inMinutes}m ${batch.finishedAt!.difference(batch.createdAt).inSeconds % 60}s',
            ),
        ],
      ),
    );
  }

  Widget _buildActorContextCard(ImportBatchUi batch) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 8),
              Text(
                'Contexto del actor',
                style: AppTextStyles.labelMd.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.secondary500.withValues(alpha: 0.15),
                child: Text(
                  batch.createdBy.isNotEmpty
                      ? batch.createdBy[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.createdBy,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                  ),
                  if (batch.actorRole != null)
                    Text(
                      batch.actorRole!,
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Inicio',
            value: DateFormat(
              'dd MMM yyyy HH:mm',
              'es',
            ).format(batch.createdAt),
          ),
          if (batch.finishedAt != null)
            _InfoRow(
              label: 'Fin',
              value: DateFormat(
                'dd MMM yyyy HH:mm',
                'es',
              ).format(batch.finishedAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictLogicCard(ImportBatchUi batch) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.merge_type_outlined,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 8),
              Text(
                'Logica de conflictos',
                style: AppTextStyles.labelMd.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ConflictRow(
            label: 'Colisiones estrictas',
            value: batch.duplicatedCount,
            color: AppColors.errorFg,
          ),
          _ConflictRow(
            label: 'Candidatos a fusion',
            value: batch.mergeCandidateCount,
            color: AppColors.warningFg,
          ),
          _ConflictRow(
            label: 'Pendiente de revision',
            value: batch.pendingReviewCount,
            color: AppColors.secondary500,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              batch.deduplicationEnabled
                  ? 'Deduplicacion: activa · nombre + geohash'
                  : 'Deduplicacion: desactivada',
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500),
            ),
          ),
        ],
      ),
    );
  }

  void _showRevertDialog(BuildContext context, ImportBatchUi batch) {
    showDialog(
      context: context,
      builder: (_) => RevertConfirmDialog(
        batch: batch,
        onConfirm: () async {
          Navigator.of(context).pop();
          await _revertBatch(batch);
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _publishBatch(ImportBatchUi batch) async {
    setState(() => _isPublishing = true);
    try {
      await _repository.publishBatch(batch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch publicado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar batch: $error')),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _revertBatch(ImportBatchUi batch) async {
    setState(() => _isReverting = true);
    try {
      await _repository.revertBatch(batch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch revertido correctamente.')),
      );
      context.go('/imports');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al revertir batch: $error')),
      );
    } finally {
      if (mounted) setState(() => _isReverting = false);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final AuditTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Línea vertical + círculo
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.result
                        ? AppColors.successFg.withValues(alpha: 0.12)
                        : AppColors.errorFg.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    event.result ? Icons.check : Icons.close,
                    size: 13,
                    color: event.result
                        ? AppColors.successFg
                        : AppColors.errorFg,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.neutral200,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Contenido del evento
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.label,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat(
                          'dd MMM · HH:mm',
                          'es',
                        ).format(event.timestamp),
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${event.actor} · ',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                      if (event.detail != null)
                        Expanded(
                          child: Text(
                            event.detail!,
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.neutral500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.headingSm.copyWith(fontSize: 18)),
            Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.neutral500,
                fontSize: 11,
              ),
            ),
          ],
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
    final (badgeKey, label) = switch (status) {
      ImportBatchStatus.completed => (
        AdminBadgeKey.importCompleted,
        'Completado',
      ),
      ImportBatchStatus.running => (AdminBadgeKey.importRunning, 'En proceso'),
      ImportBatchStatus.failed => (AdminBadgeKey.importFailed, 'Fallido'),
      ImportBatchStatus.hidden => (AdminBadgeKey.importHidden, 'En staging'),
      ImportBatchStatus.rolledBack => (
        AdminBadgeKey.importRolledBack,
        'Revertido',
      ),
      ImportBatchStatus.validated => (
        AdminBadgeKey.importValidated,
        'Validado',
      ),
      ImportBatchStatus.partial => (AdminBadgeKey.importPartial, 'Parcial'),
      ImportBatchStatus.draft => (AdminBadgeKey.importDraft, 'En cola'),
      ImportBatchStatus.archived => (AdminBadgeKey.importArchived, 'Archivado'),
    };

    return AdminSemanticBadge(badgeKey: badgeKey, label: label, compact: true);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
            ),
          ),
          Text(
            '$value',
            style: AppTextStyles.labelSm.copyWith(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.flex = 1});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral400,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _IssueTableRow extends StatelessWidget {
  const _IssueTableRow({required this.error});
  final ImportRowError error;

  @override
  Widget build(BuildContext context) {
    final isCritical = error.severity == ImportIssueSeverity.critical;
    final isError = error.severity == ImportIssueSeverity.error;
    final color = isCritical || isError
        ? AppColors.errorFg
        : AppColors.warningFg;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '#${error.row}',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  error.establishmentName,
                  style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  error.reason,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    error.severity.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.neutral100),
      ],
    );
  }
}
