import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pharmacy_duty_flow_repository.dart';
import '../domain/pharmacy_duty_flow_models.dart';
import '../services/pharmacy_duty_command_service.dart';

final pharmacyDutyCommandServiceProvider =
    Provider<PharmacyDutyCommandService>((ref) {
  return PharmacyDutyCommandService();
});

final pharmacyDutyFlowRepositoryProvider =
    Provider<PharmacyDutyFlowRepository>((ref) {
  return PharmacyDutyFlowRepository();
});

final upcomingOwnerDutyProvider =
    FutureProvider.family<PharmacyDutyFlowSummary?, String>((ref, merchantId) {
  return ref
      .watch(pharmacyDutyFlowRepositoryProvider)
      .fetchUpcomingDuty(merchantId: merchantId);
});

final dutyOpenRoundProvider =
    FutureProvider.family<DutyReassignmentRound?, String>((ref, dutyId) {
  return ref
      .watch(pharmacyDutyFlowRepositoryProvider)
      .fetchOpenRoundForDuty(dutyId: dutyId);
});

final roundRequestsProvider =
    FutureProvider.family<List<DutyReassignmentRequestItem>, String>((
  ref,
  roundId,
) {
  return ref
      .watch(pharmacyDutyFlowRepositoryProvider)
      .fetchRequestsForRound(roundId: roundId);
});

final incomingCoverageInvitationsProvider =
    FutureProvider.family<List<DutyReassignmentRequestItem>, String>((
  ref,
  merchantId,
) {
  return ref
      .watch(pharmacyDutyFlowRepositoryProvider)
      .fetchIncomingInvitations(merchantId: merchantId);
});

final invitationDetailProvider =
    FutureProvider.family<DutyInvitationDetail?, String>((ref, requestId) {
  return ref
      .watch(pharmacyDutyFlowRepositoryProvider)
      .fetchInvitationDetail(requestId: requestId);
});
