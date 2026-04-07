import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../providers/auth_providers.dart';
import 'app_router.dart';
import 'pending_route_provider.dart';
import 'router_guards.dart';

/// Dependencia inyectable del SDK de deep links.
final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// Activa el listener global de deep links de la app.
///
/// Soporta:
/// - Magic link de email (same-device y cross-device)
/// - Deep links de rutas protegidas pre-auth (pending route)
final deepLinkListenerProvider = Provider<void>((ref) {
  final controller = _DeepLinkListenerController(
    ref: ref,
    appLinks: ref.read(appLinksProvider),
    router: ref.read(appRouterProvider),
  );
  controller.start();
  ref.onDispose(controller.dispose);
});

class _DeepLinkListenerController {
  _DeepLinkListenerController({
    required this.ref,
    required this.appLinks,
    required this.router,
  });

  final Ref ref;
  final AppLinks appLinks;
  final GoRouter router;

  StreamSubscription<Uri>? _sub;
  String? _lastHandled;
  DateTime? _lastHandledAt;

  void start() {
    _sub = appLinks.uriLinkStream.listen(_onIncomingUri, onError: (_) {});
    _handleInitialUri();
  }

  Future<void> _handleInitialUri() async {
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        await _onIncomingUri(initial);
      }
    } catch (_) {}
  }

  Future<void> _onIncomingUri(Uri uri) async {
    final raw = uri.toString();
    if (_isDuplicate(raw)) return;
    _remember(raw);

    final emailLink = _extractEmailLink(uri);
    if (emailLink != null) {
      await _handleEmailSignInLink(emailLink);
      return;
    }

    final targetRoute = _extractAppRoute(uri);
    if (targetRoute == null) return;

    final authState = ref.read(authNotifierProvider).authState;
    if (authState is AuthUnauthenticated &&
        !RouterGuards.isPublicPath(targetRoute)) {
      ref.read(pendingRouteProvider.notifier).state = targetRoute;
      router.go(AppRoutes.login);
      return;
    }

    router.go(targetRoute);
  }

  Future<void> _handleEmailSignInLink(String emailLink) async {
    final authState = ref.read(authNotifierProvider).authState;
    if (authState is AuthAuthenticated) return;

    final authOpNotifier = ref.read(authOpProvider.notifier);
    final hasPendingEmail = await authOpNotifier.hasPendingEmailLink();

    if (hasPendingEmail) {
      await authOpNotifier.handleEmailLink(emailLink);
      if (ref.read(authOpProvider).errorMessage != null) {
        router.go(AppRoutes.login);
      }
      return;
    }

    ref.read(pendingMagicLinkProvider.notifier).state = emailLink;
    router.go('${AppRoutes.emailVerification}?cross_device=true');
  }

  String? _extractEmailLink(Uri incomingUri) {
    final authClient = ref.read(authClientProvider);
    final candidates = <String>[
      incomingUri.toString(),
      ..._queryLinkCandidates(incomingUri),
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (authClient.isSignInWithEmailLink(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Iterable<String> _queryLinkCandidates(Uri uri) sync* {
    for (final key in const [
      'link',
      'deep_link_id',
      'continueUrl',
      'continue_url',
    ]) {
      final value = uri.queryParameters[key];
      if (value == null || value.isEmpty) continue;
      yield value;
      try {
        yield Uri.decodeComponent(value);
      } catch (_) {}
    }
  }

  String? _extractAppRoute(Uri uri) {
    // Custom scheme opcional (ej: tum2://owner/products)
    if (uri.scheme == 'tum2') {
      final hostPart = uri.host.isEmpty ? '' : '/${uri.host}';
      final pathPart = uri.path;
      final path = '$hostPart$pathPart';
      if (path.isEmpty || path == '/auth/verify') return null;
      return _withQuery(path, uri.query);
    }

    // Deep links universales del dominio de la app
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (!_isAppHost(uri.host)) return null;
      final path = uri.path.isEmpty ? '/' : uri.path;
      if (path == '/auth/verify') return null;
      return _withQuery(path, uri.query);
    }

    // Fallback para links internos ya normalizados a path.
    if (uri.scheme.isEmpty && uri.path.startsWith('/')) {
      return _withQuery(uri.path, uri.query);
    }

    return null;
  }

  bool _isAppHost(String host) => host == 'tum2.app' || host == 'www.tum2.app';

  String _withQuery(String path, String query) =>
      query.isEmpty ? path : '$path?$query';

  bool _isDuplicate(String current) {
    if (_lastHandled != current) return false;
    final timestamp = _lastHandledAt;
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp).inSeconds < 2;
  }

  void _remember(String current) {
    _lastHandled = current;
    _lastHandledAt = DateTime.now();
  }

  void dispose() {
    _sub?.cancel();
  }
}
