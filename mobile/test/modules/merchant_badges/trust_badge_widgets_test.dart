import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_badges/domain/trust_badges.dart';
import 'package:tum2/modules/merchant_badges/widgets/trust_badge_widgets.dart';

void main() {
  testWidgets('TrustBadgeChip renderiza label correcto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrustBadgeChip(badge: TrustBadgeId.scheduleVerified),
        ),
      ),
    );

    expect(find.text('Horario verificado'), findsOneWidget);
  });

  testWidgets('TrustBadgeRow limita cantidad visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrustBadgeRow(
            badges: [
              TrustBadgeId.verifiedMerchant,
              TrustBadgeId.scheduleUpdated,
              TrustBadgeId.visibleInTum2,
            ],
            maxVisible: 1,
          ),
        ),
      ),
    );

    expect(find.byType(TrustBadgeChip), findsOneWidget);
  });

  testWidgets('badge desconocido no crashea', (tester) async {
    final parsed = parseTrustBadges(['unknown_badge']);
    expect(parsed, isEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrustBadgeRow(
            badges: parsed,
            maxVisible: 3,
          ),
        ),
      ),
    );

    expect(find.byType(TrustBadgeChip), findsNothing);
  });
}
