/// TuM2 store badge definition
class BadgeDefinition {
  final String id;
  final String key;
  final String label;
  final String description;
  final String visualStyle;
  final bool active;

  const BadgeDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.description,
    required this.visualStyle,
    required this.active,
  });

  factory BadgeDefinition.fromMap(Map<String, dynamic> data, String id) {
    return BadgeDefinition(
      id: id,
      key: data['key'] as String? ?? '',
      label: data['label'] as String? ?? '',
      description: data['description'] as String? ?? '',
      visualStyle: data['visualStyle'] as String? ?? 'default',
      active: data['active'] as bool? ?? true,
    );
  }

  // Predefined badge keys
  static const String visibleEnTuM2 = 'visible_en_tum2';
  static const String activoEnTuM2 = 'activo_en_tum2';
  static const String horarioActualizado = 'horario_actualizado';
  static const String turnoCargado = 'turno_cargado';
}

/// Badge widget display info (static, not from Firestore)
const Map<String, Map<String, dynamic>> kBadgeDisplayInfo = {
  BadgeDefinition.visibleEnTuM2: {
    'label': 'Visible en TuM2',
    'color': 0xFF1A6BFF,
    'icon': 'visibility',
  },
  BadgeDefinition.activoEnTuM2: {
    'label': 'Activo en TuM2',
    'color': 0xFF16A34A,
    'icon': 'check_circle',
  },
  BadgeDefinition.horarioActualizado: {
    'label': 'Horario actualizado',
    'color': 0xFFD97706,
    'icon': 'schedule',
  },
  BadgeDefinition.turnoCargado: {
    'label': 'Turno cargado',
    'color': 0xFF7C3AED,
    'icon': 'medical_services',
  },
};
