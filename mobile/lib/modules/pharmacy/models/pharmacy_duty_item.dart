enum PharmacyDutyPrimaryAction { call, directions }

class PharmacyDutyItem {
  const PharmacyDutyItem({
    required this.dutyId,
    required this.merchantId,
    required this.merchantName,
    required this.addressLine,
    required this.zoneId,
    required this.dutyDate,
    required this.isOnDuty,
    required this.isOpenNow,
    required this.is24Hours,
    required this.verificationStatus,
    required this.sortBoost,
    this.phone,
    this.latitude,
    this.longitude,
    this.distanceMeters,
  });

  final String dutyId;
  final String merchantId;
  final String merchantName;
  final String addressLine;
  final String zoneId;
  final String dutyDate;
  final bool isOnDuty;
  final bool isOpenNow;
  final bool is24Hours;
  final String verificationStatus;
  final int sortBoost;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int? distanceMeters;

  bool get canCall => _isValidPhone(phone);
  bool get canNavigate => latitude != null && longitude != null;

  PharmacyDutyPrimaryAction? get primaryAction {
    if (canCall) return PharmacyDutyPrimaryAction.call;
    if (canNavigate) return PharmacyDutyPrimaryAction.directions;
    return null;
  }

  PharmacyDutyItem copyWith({
    int? distanceMeters,
  }) {
    return PharmacyDutyItem(
      dutyId: dutyId,
      merchantId: merchantId,
      merchantName: merchantName,
      addressLine: addressLine,
      zoneId: zoneId,
      dutyDate: dutyDate,
      isOnDuty: isOnDuty,
      isOpenNow: isOpenNow,
      is24Hours: is24Hours,
      verificationStatus: verificationStatus,
      sortBoost: sortBoost,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  static bool isValidPhone(String? value) => _isValidPhone(value);
}

bool _isValidPhone(String? value) {
  if (value == null) return false;
  final cleaned = value.replaceAll(RegExp(r'[^0-9+]'), '');
  final digitsOnly = cleaned.replaceAll('+', '');
  return digitsOnly.length >= 6;
}
