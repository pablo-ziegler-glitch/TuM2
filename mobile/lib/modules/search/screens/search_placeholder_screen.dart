import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// SEARCH-01 — Pantalla de búsqueda (tab Buscar) placeholder.
/// Será reemplazada en TuM2-0056.
class SearchPlaceholderScreen extends StatelessWidget {
  const SearchPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      screenId: 'SEARCH-01',
      label: 'Buscar',
      navActions: [
        NavAction(
          label: 'Resultados (SEARCH-02)',
          onTap: () => context.push(AppRoutes.searchResults),
        ),
        NavAction(
          label: 'Mapa (SEARCH-03)',
          onTap: () => context.push(AppRoutes.searchMap),
        ),
      ],
    );
  }
}
