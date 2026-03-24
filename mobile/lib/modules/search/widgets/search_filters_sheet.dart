import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Panel de filtros avanzados de búsqueda.
///
/// Permite filtrar por categoría, estado operativo (abierto ahora) y
/// zona/barrio. Se muestra como bottom sheet desde el ícono de filtro
/// en la barra de búsqueda.
class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({super.key});

  /// Muestra el panel de filtros desde cualquier contexto.
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchFiltersSheet(),
    );
  }

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  String _selectedCategory = 'Todos';
  bool _abiertoAhora = false;
  bool _nivelSatisfaccion = false;
  String? _selectedZone;

  static const _categories = ['Todos', 'Restaurantes', 'Moda', 'Servicios'];
  static const _zones = [
    (name: 'Palermo', img: Icons.location_city_outlined),
    (name: 'Recoleta', img: Icons.location_city_outlined),
    (name: 'Palermo Soho', img: Icons.location_on_outlined),
  ];

  void _clearAll() {
    setState(() {
      _selectedCategory = 'Todos';
      _abiertoAhora = false;
      _nivelSatisfaccion = false;
      _selectedZone = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.zero,
                children: [
                  // Hero visual
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5A27),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(Icons.storefront_outlined,
                              color: Colors.white.withOpacity(0.1), size: 100),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 16,
                          child: Text('Descubrí tu barrio',
                              style: AppTextStyles.headingSm
                                  .copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  // Filtros avanzados header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filtros Avanzados', style: AppTextStyles.headingSm),
                        GestureDetector(
                          onTap: _clearAll,
                          child: Text('Limpiar Todo',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.primary500)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text('Refiná tu búsqueda local',
                        style: AppTextStyles.bodyXs),
                  ),
                  // Categoría
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                    child: Text('CATEGORÍA',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.neutral500, letterSpacing: 1.1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 0, 0),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 20),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          final sel = cat == _selectedCategory;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary500
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.primary500
                                      : AppColors.neutral300,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: AppTextStyles.labelMd.copyWith(
                                  color: sel
                                      ? AppColors.surface
                                      : AppColors.neutral700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Toggles
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildToggleRow(
                            icon: Icons.access_time_rounded,
                            label: 'Abierto ahora',
                            value: _abiertoAhora,
                            onChanged: (v) =>
                                setState(() => _abiertoAhora = v),
                          ),
                          Divider(color: AppColors.neutral100, height: 1),
                          _buildToggleRow(
                            icon: Icons.star_outline_rounded,
                            label: 'Nivel de satisfacción',
                            value: _nivelSatisfaccion,
                            onChanged: (v) =>
                                setState(() => _nivelSatisfaccion = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Zona o barrio
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ZONA O BARRIO',
                            style: AppTextStyles.labelSm
                                .copyWith(
                                    color: AppColors.neutral500,
                                    letterSpacing: 1.1)),
                        Text('sin marc.',
                            style: AppTextStyles.labelSm
                                .copyWith(color: AppColors.neutral400)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
                    child: SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 20),
                        itemCount: _zones.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final z = _zones[i];
                          final sel = _selectedZone == z.name;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedZone = z.name),
                            child: Container(
                              width: 110,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary500
                                    : const Color(0xFF4A6741),
                                borderRadius: BorderRadius.circular(12),
                                border: sel
                                    ? Border.all(
                                        color: AppColors.primary300, width: 2)
                                    : null,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Icon(z.img,
                                        color:
                                            Colors.white.withOpacity(0.15),
                                        size: 60),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Text(z.name,
                                        style: AppTextStyles.labelSm
                                            .copyWith(color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Botón aplicar
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'category': _selectedCategory,
                    'abiertoAhora': _abiertoAhora,
                    'zone': _selectedZone,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: AppTextStyles.labelMd,
                  ),
                  child: const Text('Aplicar Filtros'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.neutral600),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary500,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
