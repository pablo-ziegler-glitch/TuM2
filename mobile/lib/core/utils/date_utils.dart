import 'package:intl/intl.dart';

/// Date/time utility functions for TuM2
class TuM2DateUtils {
  TuM2DateUtils._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDate = DateFormat('d MMM yyyy', 'es');
  static final DateFormat _displayTime = DateFormat('HH:mm');
  static final DateFormat _relativeFormat = DateFormat.yMMMd('es');

  static String toIsoDate(DateTime date) => _dateFormat.format(date);

  static String toDisplayDate(DateTime date) => _displayDate.format(date);

  static String toDisplayTime(DateTime date) => _displayTime.format(date);

  /// Returns a human-readable relative time string.
  /// e.g. "hace 2 horas", "hace 3 días"
  static String toRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return _relativeFormat.format(date);
  }

  /// Formats freshness hours into a human-readable string.
  static String freshnessLabel(int hours) {
    if (hours >= 9999) return 'Sin datos operativos';
    if (hours < 1) return 'Actualizado hace menos de 1 hora';
    if (hours < 24) return 'Actualizado hace $hours h';
    final days = (hours / 24).round();
    return 'Actualizado hace $days días';
  }
}
