import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/discover/presentation/screens/map_screen.dart';
import '../../features/store/presentation/screens/create_store_screen.dart';
import '../../features/store/presentation/screens/edit_store_screen.dart';
import '../../features/store/presentation/screens/store_dashboard_screen.dart';
import '../../features/store/presentation/screens/public_store_screen.dart';
import '../../features/store/presentation/screens/schedule_management_screen.dart';
import '../../features/store/presentation/screens/signals_management_screen.dart';
import '../../features/product/presentation/screens/product_management_screen.dart';
import '../../features/product/presentation/screens/product_form_screen.dart';
import '../../features/pharmacy/presentation/screens/pharmacy_screen.dart';
import '../../features/roadmap/presentation/screens/roadmap_screen.dart';
import '../../features/roadmap/presentation/screens/proposal_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../widgets/main_scaffold.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }
      if (isLoggedIn && isAuthRoute && state.matchedLocation == '/auth/login') {
        return '/';
      }
      return null;
    },
    routes: [
      // ── Main shell with bottom nav ──────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'discover',
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/mapa',
            name: 'map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/farmacias',
            name: 'pharmacy',
            builder: (context, state) => const PharmacyScreen(),
          ),
          GoRoute(
            path: '/roadmap',
            name: 'roadmap',
            builder: (context, state) => const RoadmapScreen(),
          ),
          GoRoute(
            path: '/perfil',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Auth routes ─────────────────────────────────────────────────────
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/role-select',
        name: 'roleSelect',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // ── Store routes ─────────────────────────────────────────────────────
      GoRoute(
        path: '/tienda/crear',
        name: 'createStore',
        builder: (context, state) => const CreateStoreScreen(),
      ),
      GoRoute(
        path: '/tienda/:storeId',
        name: 'storeDetail',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return PublicStoreScreen(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/tienda/:storeId/editar',
        name: 'editStore',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return EditStoreScreen(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/tienda/:storeId/panel',
        name: 'storeDashboard',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return StoreDashboardScreen(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/tienda/:storeId/productos',
        name: 'productManagement',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return ProductManagementScreen(storeId: storeId);
        },
        routes: [
          GoRoute(
            path: 'nuevo',
            name: 'createProduct',
            builder: (context, state) {
              final storeId = state.pathParameters['storeId']!;
              return ProductFormScreen(storeId: storeId);
            },
          ),
          GoRoute(
            path: ':productId/editar',
            name: 'editProduct',
            builder: (context, state) {
              final storeId = state.pathParameters['storeId']!;
              final productId = state.pathParameters['productId']!;
              return ProductFormScreen(storeId: storeId, productId: productId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/tienda/:storeId/horarios',
        name: 'scheduleManagement',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return ScheduleManagementScreen(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/tienda/:storeId/senales',
        name: 'signalsManagement',
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return SignalsManagementScreen(storeId: storeId);
        },
      ),

      // ── Roadmap detail ───────────────────────────────────────────────────
      GoRoute(
        path: '/roadmap/:proposalId',
        name: 'proposalDetail',
        builder: (context, state) {
          final proposalId = state.pathParameters['proposalId']!;
          return ProposalDetailScreen(proposalId: proposalId);
        },
      ),
    ],
  );
}
