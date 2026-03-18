import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/proposal_model.dart';
import '../providers/roadmap_providers.dart';

class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(roadmapSegmentProvider);
    final proposalsAsync = ref.watch(proposalsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ideas'),
        bottom: TabBar(
          controller: TabController(
            length: 2,
            vsync: Navigator.of(context),
            initialIndex:
                segment == ProposalSegment.customer ? 0 : 1,
          ),
          onTap: (i) {
            ref.read(roadmapSegmentProvider.notifier).state =
                i == 0 ? ProposalSegment.customer : ProposalSegment.owner;
          },
          tabs: const [
            Tab(text: 'Clientes'),
            Tab(text: 'Comerciantes'),
          ],
        ),
      ),
      floatingActionButton: user != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref, user.id, segment),
              icon: const Icon(Icons.add),
              label: const Text('Proponer'),
            )
          : null,
      body: proposalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (proposals) {
          if (proposals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 64, color: TuM2Colors.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Aún no hay propuestas.',
                      style: TuM2TextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text('Sé el primero en proponer algo.',
                      style: TuM2TextStyles.bodySmall
                          .copyWith(color: TuM2Colors.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: proposals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final p = proposals[i];
              return _ProposalCard(
                proposal: p,
                userId: user?.id,
                onTap: () => context.push('/roadmap/${p.id}'),
                onVote: user != null
                    ? () => ref
                        .read(proposalRepositoryProvider)
                        .toggleVote(
                          proposalId: p.id,
                          userId: user.id,
                          segment:
                              segment == ProposalSegment.owner ? 'OWNER' : 'CUSTOMER',
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(
      BuildContext context,
      WidgetRef ref,
      String userId,
      ProposalSegment segment) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva propuesta', style: TuM2TextStyles.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await ref.read(proposalRepositoryProvider).createProposal(
                      createdBy: userId,
                      segment: segment,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                    );
              },
              child: const Text('Enviar propuesta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final ProposalModel proposal;
  final String? userId;
  final VoidCallback onTap;
  final VoidCallback? onVote;

  const _ProposalCard({
    required this.proposal,
    required this.userId,
    required this.onTap,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: TuM2Colors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proposal.title, style: TuM2TextStyles.titleMedium),
                  if (proposal.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      proposal.description,
                      style: TuM2TextStyles.bodySmall
                          .copyWith(color: TuM2Colors.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: TuM2Colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(proposal.statusLabel,
                        style: TuM2TextStyles.labelSmall),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Vote button
            GestureDetector(
              onTap: onVote,
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: onVote != null
                        ? TuM2Colors.primary
                        : TuM2Colors.onSurfaceVariant,
                    size: 28,
                  ),
                  Text(
                    '${proposal.voteCount}',
                    style: TuM2TextStyles.titleMedium.copyWith(
                      color: onVote != null
                          ? TuM2Colors.primary
                          : TuM2Colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
