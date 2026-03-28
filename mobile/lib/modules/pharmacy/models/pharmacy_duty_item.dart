import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ── Nivel de confianza del turno ─────────────────────────────────────────────

/// Nivel de confianza derivado del verificationStatus del merchant y la fuente del turno.
enum PharmacyTrustLevel {
  /// Verificado por fuente oficial (ministerio, colegio farmacéutico).
  official,
  /// Verificado por el dueño o validado por el equipo TuM2.
  verified,
  /// Aportado por la comunidad.
  community,
  /// Sin verificar.
  unverified,
}

// ── Modelo principal ──────────────────────────────────────────────────────────

/// Combina un documento de pharmacy_duties con los datos hidratados de merchant_public.
class PharmacyDutyItem {
  /// ID del documento en pharmacy_duties.
  final String dutyId;

  /// ID del merchant en Firestore.
  final String merchantId;

  /// Nombre de la farmacia.
  final String name;

  /// Dirección de la farmacia.
  final String address;

  /// Teléfono de la farmacia. Puede ser null — en ese caso no se muestra el botón "Llamar".
  final String? phone;

  /// Latitud. Puede ser null — en ese caso no se muestra distancia ni "Cómo llegar".
  final double? lat;

  /// Longitud. Puede ser null.
  final double? lng;

  /// Inicio del turno (en timezone local del dispositivo).
  final DateTime startsAt;

  /// Fin del turno (en timezone local del dispositivo).
  final DateTime endsAt;

  /// Fecha del turno en formato YYYY-MM-DD (timezone Argentina).
  final String date;

  /// ID de la zona.
  final String zoneId;

  /// verificationStatus del merchant_public.
  final String verificationStatus;

  /// verificationStatus propio del turno (pharmacy_duties.verificationStatus).
  final String dutyVerificationStatus;

  /// Score de confianza 0–100 del merchant_public.
  final double? confidenceScore;

  /// Distancia en metros respecto a la posición del usuario. Se calcula en cliente.
  /// Null si no se dispone de coordenadas del merchant o del usuario.
  int? distanceMeters;

  PharmacyDutyItem({
    required this.dutyId,
    required this.merchantId,
    required this.name,
    required this.address,
    this.phone,
    this.lat,
    this.lng,
    required this.startsAt,
    required this.endsAt,
    required this.date,
    required this.zoneId,
    required this.verificationStatus,
    required this.dutyVerificationStatus,
    this.confidenceScore,
    this.distanceMeters,
  });

  // ── Derivados de presentación ─────────────────────────────────────────────

  /// Nivel de confianza calculado a partir del verificationStatus del merchant.
  PharmacyTrustLevel get trustLevel {
    switch (verificationStatus) {
      case 'verified':
        return PharmacyTrustLevel.official;
      case 'validated':
        return PharmacyTrustLevel.verified;
      case 'claimed':
      case 'community_submitted':
        return PharmacyTrustLevel.community;
      default:
        return PharmacyTrustLevel.unverified;
    }
  }

  /// Texto de "hasta qué hora" con lenguaje natural.
  /// Ej: "hasta mañana 08:30" o "hasta las 22:00".
  String get dutyUntilLabel {
    final now = DateTime.now();
    final isNextDay = endsAt.day != now.day ||
        endsAt.month != now.month ||
        endsAt.year != now.year;
    final timeStr = DateFormat('HH:mm').format(endsAt);
    return isNextDay ? 'hasta mañana $timeStr' : 'hasta las $timeStr';
  }

  /// Etiqueta del turno en mayúsculas para el badge del detalle.
  /// Ej: "DE TURNO HASTA MAÑANA 08:30".
  String get dutyBadgeLabel {
    final now = DateTime.now();
    final isNextDay = endsAt.day != now.day ||
        endsAt.month != now.month ||
        endsAt.year != now.year;
    final timeStr = DateFormat('HH:mm').format(endsAt);
    return isNextDay
        ? 'DE TURNO HASTA MAÑANA $timeStr'
        : 'DE TURNO HASTA LAS $timeStr';
  }

  // ── Fábrica desde Firestore ───────────────────────────────────────────────

  /// Crea un [PharmacyDutyItem] a partir de un documento de pharmacy_duties y
  /// los datos de merchant_public correspondientes.
  factory PharmacyDutyItem.fromFirestore({
    required String dutyId,
    required Map<String, dynamic> dutyData,
    required Map<String, dynamic> merchantData,
  }) {
    final startsAtTs = dutyData['startsAt'];
    final endsAtTs = dutyData['endsAt'];

    final startsAt = startsAtTs is Timestamp
        ? startsAtTs.toDate().toLocal()
        : DateTime.now();
    final endsAt = endsAtTs is Timestamp
        ? endsAtTs.toDate().toLocal()
        : DateTime.now().add(const Duration(hours: 8));

    return PharmacyDutyItem(
      dutyId: dutyId,
      merchantId: dutyData['merchantId'] as String? ?? '',
      name: merchantData['name'] as String? ?? '',
      address: merchantData['address'] as String? ?? '',
      phone: merchantData['phone'] as String?,
      lat: (merchantData['lat'] as num?)?.toDouble(),
      lng: (merchantData['lng'] as num?)?.toDouble(),
      startsAt: startsAt,
      endsAt: endsAt,
      date: dutyData['date'] as String? ?? '',
      zoneId: dutyData['zoneId'] as String? ?? '',
      verificationStatus:
          merchantData['verificationStatus'] as String? ?? 'unverified',
      dutyVerificationStatus:
          dutyData['verificationStatus'] as String? ?? 'referential',
      confidenceScore: (merchantData['confidenceScore'] as num?)?.toDouble(),
    );
  }
}
