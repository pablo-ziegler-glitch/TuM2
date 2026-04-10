import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tum2/main.dart';
import 'package:tum2/core/router/app_router.dart';
import 'package:tum2/core/router/deep_link_listener.dart';

void main() {
  testWidgets('TuM2App monta sin errores', (tester) async {
    final testRouter = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(testRouter),
          deepLinkListenerProvider.overrideWithValue(null),
        ],
        child: const TuM2App(),
      ),
    );
    expect(find.byType(TuM2App), findsOneWidget);
  });
}
