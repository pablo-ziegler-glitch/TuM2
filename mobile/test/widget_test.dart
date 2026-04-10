import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tum2/main.dart';

void main() {
  testWidgets('TuM2App monta sin errores', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TuM2App(),
      ),
    );
    expect(find.byType(TuM2App), findsOneWidget);
  });
}
