import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.isColdStart,
    required this.query,
    this.isZoneWithoutData = false,
    this.openNowActive = false,
    this.onSuggestCommerce,
  });

  final bool isColdStart;
  final String query;
  final bool isZoneWithoutData;
  final bool openNowActive;
  final VoidCallback? onSuggestCommerce;

  @override
  Widget build(BuildContext context) {
    final title = isZoneWithoutData
        ? 'Esta zona todavia no tiene comercios publicados'
        : openNowActive
            ? 'No hay comercios abiertos ahora'
            : isColdStart
                ? 'Aun no hay comercios verificados en esta zona'
                : 'Sin resultados para "$query"';
    final subtitle = isZoneWithoutData
        ? 'Proba cambiando de zona para ampliar el catalogo.'
        : openNowActive
            ? 'Podes desactivar el filtro para ver comercios sin horarios cargados.'
            : isColdStart
                ? 'Mostramos comercios pendientes para que igual puedas orientarte.'
                : 'Proba con otra busqueda o cambia los filtros.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_outlined,
                color: AppColors.neutral500,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSuggestCommerce,
              icon: const Icon(Icons.add_business_outlined, size: 16),
              label: const Text('Conoces un comercio? Sugerilo'),
            ),
          ],
        ),
      ),
    );
  }
}
