import 'package:cloud_firestore/cloud_firestore.dart';

enum SignalType { hs24, lateNight, specialHours, specialService, nightDelivery }

enum SignalStatus { active, inactive }

enum SignalSourceType { owner, admin, system }

class OperationalSignalModel {
  final String id;
  final String storeId;
  final SignalType signalType;
  final SignalStatus status;
  final String notes;
  final SignalSourceType sourceType;
  final String confidenceLevel;
  final DateTime updatedAt;

  const OperationalSignalModel({
    required this.id,
    required this.storeId,
    required this.signalType,
    required this.status,
    required this.notes,
    required this.sourceType,
    required this.confidenceLevel,
    required this.updatedAt,
  });

  bool get isActive => status == SignalStatus.active;

  factory OperationalSignalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OperationalSignalModel(
      id: doc.id,
      storeId: data['storeId'] as String? ?? '',
      signalType: _parseType(data['signalType'] as String? ?? ''),
      status: (data['status'] as String?) == 'active'
          ? SignalStatus.active
          : SignalStatus.inactive,
      notes: data['notes'] as String? ?? '',
      sourceType: _parseSource(data['sourceType'] as String? ?? 'owner'),
      confidenceLevel: data['confidenceLevel'] as String? ?? 'medium',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'storeId': storeId,
        'signalType': _typeToString(signalType),
        'status': status == SignalStatus.active ? 'active' : 'inactive',
        'notes': notes,
        'sourceType': _sourceToString(sourceType),
        'confidenceLevel': confidenceLevel,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static SignalType _parseType(String value) {
    switch (value) {
      case '24hs': return SignalType.hs24;
      case 'late_night': return SignalType.lateNight;
      case 'special_hours': return SignalType.specialHours;
      case 'special_service': return SignalType.specialService;
      case 'night_delivery': return SignalType.nightDelivery;
      default: return SignalType.specialHours;
    }
  }

  static String _typeToString(SignalType type) {
    switch (type) {
      case SignalType.hs24: return '24hs';
      case SignalType.lateNight: return 'late_night';
      case SignalType.specialHours: return 'special_hours';
      case SignalType.specialService: return 'special_service';
      case SignalType.nightDelivery: return 'night_delivery';
    }
  }

  static SignalSourceType _parseSource(String value) {
    switch (value) {
      case 'admin': return SignalSourceType.admin;
      case 'system': return SignalSourceType.system;
      default: return SignalSourceType.owner;
    }
  }

  static String _sourceToString(SignalSourceType source) {
    switch (source) {
      case SignalSourceType.owner: return 'owner';
      case SignalSourceType.admin: return 'admin';
      case SignalSourceType.system: return 'system';
    }
  }

  // Signal display metadata
  static const Map<SignalType, Map<String, dynamic>> displayInfo = {
    SignalType.hs24: {
      'label': '24 horas',
      'description': 'Abierto las 24 horas',
      'icon': 'access_time',
    },
    SignalType.lateNight: {
      'label': 'Hasta tarde',
      'description': 'Horario extendido nocturno',
      'icon': 'nightlight_round',
    },
    SignalType.specialHours: {
      'label': 'Horario especial',
      'description': 'Horario temporal modificado',
      'icon': 'event',
    },
    SignalType.specialService: {
      'label': 'Servicio especial',
      'description': 'Servicio o promoción especial activa',
      'icon': 'star_outline',
    },
    SignalType.nightDelivery: {
      'label': 'Delivery nocturno',
      'description': 'Entrega disponible en horario nocturno',
      'icon': 'delivery_dining',
    },
  };
}
