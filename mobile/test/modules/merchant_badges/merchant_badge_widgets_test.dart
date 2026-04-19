import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_visual_models.dart';
import 'package:tum2/modules/merchant_badges/widgets/merchant_badge_widgets.dart';

void main() {
  testWidgets('compact mode usa label Abierto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MerchantStatusBadge(
            badge: MerchantBadgeKey.openNow,
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('Abierto'), findsOneWidget);
    expect(find.text('Abierto ahora'), findsNothing);
  });
}
