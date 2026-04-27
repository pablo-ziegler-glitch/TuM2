import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_badges/domain/operational_status_resolver.dart';
import 'package:tum2/modules/merchant_badges/domain/trust_badges.dart';

void main() {
  MerchantScheduleSummary summaryFixture() {
    return const MerchantScheduleSummary(
      timezone: 'America/Argentina/Buenos_Aires',
      hasSchedule: true,
      todayWindows: [
        MerchantScheduleSummaryWindow(
          opensAtLocalMinutes: 9 * 60,
          closesAtLocalMinutes: 18 * 60,
        ),
      ],
    );
  }

  test('resolveOperationalStatus devuelve abierto dentro de ventana', () {
    final result = resolveOperationalStatus(
      now: DateTime(2026, 4, 27, 10, 0),
      merchant: MerchantOperationalProjection(
        scheduleSummary: summaryFixture(),
        nextOpenAt: DateTime(2026, 4, 28, 9, 0),
        nextCloseAt: DateTime(2026, 4, 27, 18, 0),
        nextTransitionAt: DateTime(2026, 4, 27, 18, 0),
        hasOperationalSignal: false,
        operationalSignalType: 'none',
        operationalStatusLabel: null,
      ),
    );
    expect(result.type, ResolvedOperationalStatusType.openNow);
  });

  test('resolveOperationalStatus devuelve cerrado fuera de ventana', () {
    final result = resolveOperationalStatus(
      now: DateTime(2026, 4, 27, 21, 0),
      merchant: MerchantOperationalProjection(
        scheduleSummary: summaryFixture(),
        nextOpenAt: DateTime(2026, 4, 28, 9, 0),
        nextCloseAt: DateTime(2026, 4, 28, 18, 0),
        nextTransitionAt: DateTime(2026, 4, 28, 9, 0),
        hasOperationalSignal: false,
        operationalSignalType: 'none',
        operationalStatusLabel: null,
      ),
    );
    expect(result.type, ResolvedOperationalStatusType.closedNow);
  });

  test('temporary_closure fuerza cerrado', () {
    final result = resolveOperationalStatus(
      now: DateTime(2026, 4, 27, 10, 0),
      merchant: MerchantOperationalProjection(
        scheduleSummary: summaryFixture(),
        nextOpenAt: null,
        nextCloseAt: null,
        nextTransitionAt: null,
        hasOperationalSignal: true,
        operationalSignalType: 'temporary_closure',
        operationalStatusLabel: null,
      ),
    );
    expect(result.type, ResolvedOperationalStatusType.temporaryClosed);
  });

  test('vacation fuerza cerrado', () {
    final result = resolveOperationalStatus(
      now: DateTime(2026, 4, 27, 10, 0),
      merchant: MerchantOperationalProjection(
        scheduleSummary: summaryFixture(),
        nextOpenAt: null,
        nextCloseAt: null,
        nextTransitionAt: null,
        hasOperationalSignal: true,
        operationalSignalType: 'vacation',
        operationalStatusLabel: null,
      ),
    );
    expect(result.type, ResolvedOperationalStatusType.vacation);
  });

  test('delay no rompe calculo', () {
    final result = resolveOperationalStatus(
      now: DateTime(2026, 4, 27, 10, 0),
      merchant: MerchantOperationalProjection(
        scheduleSummary: summaryFixture(),
        nextOpenAt: DateTime(2026, 4, 27, 11, 0),
        nextCloseAt: DateTime(2026, 4, 27, 18, 0),
        nextTransitionAt: DateTime(2026, 4, 27, 11, 0),
        hasOperationalSignal: true,
        operationalSignalType: 'delay',
        operationalStatusLabel: null,
      ),
    );
    expect(result.type, ResolvedOperationalStatusType.delayed);
  });
}
