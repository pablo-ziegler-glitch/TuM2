import 'package:intl/intl.dart';

DateTime businessNowUtcMinus3() {
  return DateTime.now().toUtc().subtract(const Duration(hours: 3));
}

DateTime businessTodayUtcMinus3() {
  final now = businessNowUtcMinus3();
  return DateTime(now.year, now.month, now.day);
}

DateTime normalizeBusinessDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String businessDateKey(DateTime value) {
  return DateFormat('yyyy-MM-dd').format(normalizeBusinessDate(value));
}

String businessDateLabel(DateTime value) {
  return DateFormat('dd/MM/yyyy').format(normalizeBusinessDate(value));
}

String businessDateSelectorLabel(DateTime value) {
  final today = businessTodayUtcMinus3();
  final normalized = normalizeBusinessDate(value);
  if (normalized == today) return 'Hoy';
  return businessDateLabel(normalized);
}
