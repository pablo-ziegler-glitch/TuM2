import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/pharmacy_duty_flow_models.dart';

class PharmacyDutyFlowRepository {
  PharmacyDutyFlowRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _timeout = Duration(seconds: 8);

  Future<PharmacyDutyFlowSummary?> fetchUpcomingDuty({
    required String merchantId,
  }) async {
    final today = _dateKey(DateTime.now());
    final snap = await _firestore
        .collection('pharmacy_duties')
        .where('merchantId', isEqualTo: merchantId)
        .where('date', isGreaterThanOrEqualTo: today)
        .orderBy('date')
        .limit(10)
        .get()
        .timeout(_timeout);

    for (final doc in snap.docs) {
      final summary = PharmacyDutyFlowSummary.fromFirestore(doc.id, doc.data());
      if (summary.status != 'cancelled') {
        return summary;
      }
    }
    return null;
  }

  Future<DutyReassignmentRound?> fetchOpenRoundForDuty({
    required String dutyId,
  }) async {
    final snap = await _firestore
        .collection('pharmacy_duty_reassignment_rounds')
        .where('dutyId', isEqualTo: dutyId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get()
        .timeout(_timeout);
    if (snap.docs.isEmpty) return null;
    return DutyReassignmentRound.fromFirestore(
      snap.docs.first.id,
      snap.docs.first.data(),
    );
  }

  Future<List<DutyReassignmentRequestItem>> fetchRequestsForRound({
    required String roundId,
  }) async {
    final snap = await _firestore
        .collection('pharmacy_duty_reassignment_requests')
        .where('roundId', isEqualTo: roundId)
        .get()
        .timeout(_timeout);

    final items = snap.docs
        .map((doc) => DutyReassignmentRequestItem.fromFirestore(
              doc.id,
              doc.data(),
            ))
        .toList(growable: false);
    items.sort((a, b) => a.status.compareTo(b.status));
    return items;
  }

  Future<List<DutyReassignmentRequestItem>> fetchIncomingInvitations({
    required String merchantId,
  }) async {
    final snap = await _firestore
        .collection('pharmacy_duty_reassignment_requests')
        .where('candidateMerchantId', isEqualTo: merchantId)
        .where('status', isEqualTo: 'pending')
        .orderBy('expiresAt')
        .limit(20)
        .get()
        .timeout(_timeout);

    return snap.docs
        .map((doc) => DutyReassignmentRequestItem.fromFirestore(
              doc.id,
              doc.data(),
            ))
        .toList(growable: false);
  }

  Future<DutyInvitationDetail?> fetchInvitationDetail({
    required String requestId,
  }) async {
    final requestSnap = await _firestore
        .doc('pharmacy_duty_reassignment_requests/$requestId')
        .get()
        .timeout(_timeout);
    if (!requestSnap.exists) return null;
    final request = DutyReassignmentRequestItem.fromFirestore(
        requestSnap.id, requestSnap.data()!);

    final dutySnap = await _firestore
        .doc('pharmacy_duties/${request.dutyId}')
        .get()
        .timeout(_timeout);
    if (!dutySnap.exists) return null;
    final duty =
        PharmacyDutyFlowSummary.fromFirestore(dutySnap.id, dutySnap.data()!);

    final merchantSnap = await _firestore
        .doc('merchants/${request.originMerchantId}')
        .get()
        .timeout(_timeout);
    final originName = (merchantSnap.data()?['name'] as String?)?.trim() ??
        request.originMerchantId;

    return DutyInvitationDetail(
      request: request,
      duty: duty,
      originMerchantName: originName,
    );
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
