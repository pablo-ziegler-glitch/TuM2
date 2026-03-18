import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/proposal_model.dart';
import '../providers/roadmap_providers.dart';

class ProposalDetailScreen extends ConsumerWidget {
  final String proposalId;

  const ProposalDetailScreen({super.key, required this.proposalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return FutureBuilder<ProposalModel?>(
      future: ref.read(proposalRepositoryProvider).getProposal(proposalId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final proposal = snap.data;
        if (proposal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Propuesta no encontrada')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Propuesta'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => Share.share(
                  'TuM2 — ${proposal.title}\n\nVotá esta propuesta: tum2.app/roadmap/${proposal.id}',
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TuM2Colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(proposal.statusLabel,
                      style: TuM2TextStyles.labelSmall),
                ),
                const SizedBox(height: 12),
                Text(proposal.title, style: TuM2TextStyles.headlineLarge),
                const SizedBox(height: 12),
                Text(proposal.description, style: TuM2TextStyles.bodyLarge),
                const Spacer(),
                // Vote section
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${proposal.voteCount}',
                        style: TuM2TextStyles.displayLarge
                            .copyWith(color: TuM2Colors.primary),
                      ),
                      Text('votos',
                          style: TuM2TextStyles.bodyMedium
                              .copyWith(color: TuM2Colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      if (user != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(proposalRepositoryProvider)
                                .toggleVote(
                                  proposalId: proposal.id,
                                  userId: user.id,
                                  segment:
                                      proposal.segment == ProposalSegment.owner
                                          ? 'OWNER'
                                          : 'CUSTOMER',
                                );
                          },
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          label: const Text('Votar esta propuesta'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
