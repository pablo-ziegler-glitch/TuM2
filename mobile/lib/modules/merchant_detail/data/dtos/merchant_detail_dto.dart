import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantCoreDto {
  const MerchantCoreDto({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  factory MerchantCoreDto.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return MerchantCoreDto(
      id: document.id,
      data: document.data() ?? const {},
    );
  }
}

class PharmacyDutyDto {
  const PharmacyDutyDto({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  factory PharmacyDutyDto.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return PharmacyDutyDto(
      id: document.id,
      data: document.data(),
    );
  }
}

class MerchantProductDto {
  const MerchantProductDto({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  factory MerchantProductDto.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return MerchantProductDto(
      id: document.id,
      data: document.data(),
    );
  }
}

class MerchantScheduleDto {
  const MerchantScheduleDto({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  factory MerchantScheduleDto.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return MerchantScheduleDto(
      id: document.id,
      data: document.data() ?? const {},
    );
  }
}

class MerchantOperationalSignalsDto {
  const MerchantOperationalSignalsDto({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  factory MerchantOperationalSignalsDto.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return MerchantOperationalSignalsDto(
      id: document.id,
      data: document.data() ?? const {},
    );
  }
}
