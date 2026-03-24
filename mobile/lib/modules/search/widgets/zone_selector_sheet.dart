import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Bottom sheet para seleccionar la zona/barrio activo del usuario.
///
/// Se muestra cuando el usuario toca "Mi zona" en los accesos rápidos o el
/// ícono de ubicación en el header. Permite usar GPS o elegir manualmente
/// un barrio de la lista de cercanos.
class ZoneSelectorSheet extends StatefulWidget {
  const ZoneSelectorSheet({super.key});

  /// Muestra el sheet desde cualquier contexto con [showModalBottomSheet].
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ZoneSelectorSheet(),
    );
  }

  @override
  State<ZoneSelectorSheet> createState() => _ZoneSelectorSheetState();
}

class _ZoneSelectorSheetState extends State<ZoneSelectorSheet> {
  String? _selected;

  static const _barrios = [
    (name: 'Palermo', sub: 'Buenos Aires, CABA', icon: Icons.location_city_outlined),
    (name: 'Recoleta', sub: 'Buenos Aires, CABA', icon: Icons.location_city_outlined),
    (name: 'Puerto Madero', sub: 'Buenos Aires, CABA', icon: Icons.water_outlined),
    (name: 'Belgrano', sub: 'Buenos Aires, CABA', icon: Icons.location_on_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seleccionar Zona', style: AppTextStyles.headingSm),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                      backgroundColor: AppColors.neutral100,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),
            // Mini mapa placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6741),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.map_outlined,
                          size: 60, color: Colors.white.withOpacity(0.2)),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.my_location, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text('Mi ubicación',
                                  style: AppTextStyles.labelSm.copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botón GPS
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'gps'),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('USAR MI UBICACIÓN ACTUAL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                    side: const BorderSide(color: AppColors.primary500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: AppTextStyles.labelMd,
                  ),
                ),
              ),
            ),
            // Lista de barrios
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text('BARRIOS CERCANOS',
                      style: AppTextStyles.labelSm
                          .copyWith(color: AppColors.neutral500, letterSpacing: 1.1)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _barrios.length,
                itemBuilder: (_, i) {
                  final b = _barrios[i];
                  final isSelected = _selected == b.name;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = b.name),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary50 : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary300 : AppColors.neutral200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary100 : AppColors.neutral100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(b.icon,
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary500
                                    : AppColors.neutral600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.name, style: AppTextStyles.labelMd),
                                Text(b.sub, style: AppTextStyles.bodyXs),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary500, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Confirmar
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selected != null
                      ? () => Navigator.pop(context, _selected)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: AppTextStyles.labelMd,
                  ),
                  child: const Text('Confirmar Ubicación'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
