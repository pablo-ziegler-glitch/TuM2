import 'package:cloud_firestore/cloud_firestore.dart';

enum ProposalStatus { open, inReview, planned, done, rejected }
enum ModerationStatus { pending, approved, rejected }
enum ProposalSegment { owner, customer }

class ProposalModel {
  final String id;
  final ProposalSegment segment;
  final String createdBy;
  final String title;
  final String description;
  final ProposalStatus status;
  final int voteCount;
  final String shareSlug;
  final ModerationStatus moderationStatus;
  final DateTime createdAt;

  const ProposalModel({
    required this.id,
    required this.segment,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.status,
    required this.voteCount,
    required this.shareSlug,
    required this.moderationStatus,
    required this.createdAt,
  });

  factory ProposalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProposalModel(
      id: doc.id,
      segment: _parseSegment(data['segment'] as String? ?? 'CUSTOMER'),
      createdBy: data['createdBy'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: _parseStatus(data['status'] as String? ?? 'open'),
      voteCount: data['voteCount'] as int? ?? 0,
      shareSlug: data['shareSlug'] as String? ?? '',
      moderationStatus:
          _parseModerationStatus(data['moderationStatus'] as String? ?? 'pending'),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static ProposalSegment _parseSegment(String v) =>
      v == 'OWNER' ? ProposalSegment.owner : ProposalSegment.customer;

  static ProposalStatus _parseStatus(String v) {
    switch (v) {
      case 'in_review': return ProposalStatus.inReview;
      case 'planned': return ProposalStatus.planned;
      case 'done': return ProposalStatus.done;
      case 'rejected': return ProposalStatus.rejected;
      default: return ProposalStatus.open;
    }
  }

  static ModerationStatus _parseModerationStatus(String v) {
    switch (v) {
      case 'approved': return ModerationStatus.approved;
      case 'rejected': return ModerationStatus.rejected;
      default: return ModerationStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case ProposalStatus.open: return 'Abierta';
      case ProposalStatus.inReview: return 'En revisión';
      case ProposalStatus.planned: return 'Planificada';
      case ProposalStatus.done: return 'Implementada';
      case ProposalStatus.rejected: return 'Rechazada';
    }
  }
}
