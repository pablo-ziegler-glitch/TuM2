import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/proposal_model.dart';

class ProposalRepository {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  ProposalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Streams approved proposals for a given segment, sorted by vote count.
  Stream<List<ProposalModel>> watchProposals(ProposalSegment segment) {
    final segStr = segment == ProposalSegment.owner ? 'OWNER' : 'CUSTOMER';
    return _db
        .collection('proposals')
        .where('segment', isEqualTo: segStr)
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('voteCount', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ProposalModel.fromFirestore(doc)).toList());
  }

  /// Fetches a single proposal by ID.
  Future<ProposalModel?> getProposal(String id) async {
    final snap = await _db.collection('proposals').doc(id).get();
    if (!snap.exists) return null;
    return ProposalModel.fromFirestore(snap);
  }

  /// Creates a new proposal.
  Future<String> createProposal({
    required String createdBy,
    required ProposalSegment segment,
    required String title,
    required String description,
  }) async {
    final id = _uuid.v4();
    final segStr = segment == ProposalSegment.owner ? 'OWNER' : 'CUSTOMER';
    final slug = title.toLowerCase().replaceAll(' ', '-').replaceAll(
        RegExp(r'[^a-z0-9-]'), '');

    await _db.collection('proposals').doc(id).set({
      'id': id,
      'segment': segStr,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'status': 'open',
      'voteCount': 0,
      'shareSlug': '$slug-$id'.substring(0, 40.clamp(0, ('$slug-$id').length)),
      'moderationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  /// Adds or removes a vote for a proposal.
  Future<void> toggleVote({
    required String proposalId,
    required String userId,
    required String segment,
  }) async {
    final voteRef = _db
        .collection('proposals')
        .doc(proposalId)
        .collection('votes')
        .doc(userId);

    final snap = await voteRef.get();

    if (snap.exists) {
      // Remove vote
      await voteRef.delete();
    } else {
      // Add vote
      await voteRef.set({
        'proposalId': proposalId,
        'userId': userId,
        'segment': segment,
        'voteType': 'up',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Checks if the user has voted for a proposal.
  Future<bool> hasVoted(String proposalId, String userId) async {
    final snap = await _db
        .collection('proposals')
        .doc(proposalId)
        .collection('votes')
        .doc(userId)
        .get();
    return snap.exists;
  }
}
