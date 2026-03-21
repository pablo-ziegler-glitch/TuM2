// Re-export all shared domain types from the TuM2 schema package.
// The path assumes the schema lives at ../../schema relative to this file
// (i.e., /home/user/TuM2/schema).
//
// If the schema is published as an npm package or a workspace reference,
// update the import path accordingly.
export type {
  // Users
  UserDocument,
  UserRole,
  UserStatus,

  // Zones
  ZoneDocument,
  ZoneStatus,
  ZoneLaunchPhase,
  ZoneBounds,
  ZoneCoverageMetrics,

  // Merchants
  MerchantDocument,
  MerchantStatus,
  MerchantVisibilityStatus,
  MerchantVerificationStatus,
  MerchantSourceType,
  MerchantLocation,
  MerchantContact,

  // Merchant public view
  MerchantPublicDocument,
  MerchantBadge,
  OperationalSignalsSnapshot,

  // Schedules
  MerchantSchedulesDocument,
  WeeklySchedule,
  DaySchedule,
  DayOfWeek,
  ScheduleSlot,
  ScheduleException,

  // Operational signals
  MerchantOperationalSignalsDocument,
  OperationalSignals,
  DerivedSignals,
  IsOpenNowSource,
  IsOpenNowConfidence,

  // Products
  MerchantProductDocument,
  ProductStatus,
  ProductVisibilityStatus,
  ProductStockStatus,

  // Pharmacy duties
  PharmacyDutyDocument,
  PharmacyDutyStatus,
  PharmacyDutyVerificationStatus,

  // External places
  ExternalPlaceDocument,
  ExternalPlaceSource,
  ExternalPlaceImportStatus,

  // Import batches
  ImportBatchDocument,
  ImportBatchStatus,

  // Claims
  MerchantClaimDocument,
  MerchantClaimStatus,
  ClaimEvidence,

  // Reports
  ReportDocument,
  ReportTargetType,
  ReportType,
  ReportStatus,

  // Admin configs
  AdminConfigGlobal,
  ZonePublicationRules,
  BootstrapRules,
  FeatureFlags,
} from '../../schema/types/index';
