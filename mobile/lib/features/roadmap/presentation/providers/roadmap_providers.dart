import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/proposal_repository.dart';
import '../../domain/proposal_model.dart';

final proposalRepositoryProvider = Provider<ProposalRepository>((ref) {
  return ProposalRepository();
});

/// Active segment tab selection (owner / customer)
final roadmapSegmentProvider =
    StateProvider<ProposalSegment>((ref) => ProposalSegment.customer);

/// Proposals for the current segment
final proposalsProvider = StreamProvider<List<ProposalModel>>((ref) {
  final segment = ref.watch(roadmapSegmentProvider);
  return ref.watch(proposalRepositoryProvider).watchProposals(segment);
});
