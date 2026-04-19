import { OperationalSignals } from "./types";

export type MerchantOperationalSignalType =
  | "none"
  | "vacation"
  | "temporary_closure"
  | "delay";

export type ManualOverrideMode = "none" | "force_closed" | "informational";

export interface OperationalPublicState {
  hasOperationalSignal: boolean;
  operationalSignalType: MerchantOperationalSignalType;
  operationalSignalMessage: string | null;
  manualOverrideMode: ManualOverrideMode;
  operationalStatusLabel: string | null;
  isOpenNow: boolean;
  todayScheduleLabel: string;
  hasPharmacyDutyToday: boolean;
  operationalSignals: Record<string, unknown>;
}

function normalizeSignalType(value: unknown): MerchantOperationalSignalType {
  if (
    value === "none" ||
    value === "vacation" ||
    value === "temporary_closure" ||
    value === "delay"
  ) {
    return value;
  }
  return "none";
}

function normalizeMessage(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, 80);
}

function readLegacyTemporaryClosed(raw: Record<string, unknown>): boolean {
  if (raw.temporaryClosed === true) return true;
  const nested = raw.signals;
  if (!nested || typeof nested !== "object") return false;
  return (nested as Record<string, unknown>).temporaryClosed === true;
}

function sanitizeManualSignal(raw: Record<string, unknown>): {
  type: MerchantOperationalSignalType;
  isActive: boolean;
  message: string | null;
  forceClosed: boolean;
} {
  const signalType = normalizeSignalType(raw.signalType);
  const isActiveRaw = raw.isActive === true;
  const message = normalizeMessage(raw.message);

  // Compatibilidad con payload legacy temporal.
  if (!isActiveRaw && signalType === "none" && readLegacyTemporaryClosed(raw)) {
    return {
      type: "temporary_closure",
      isActive: true,
      message: normalizeMessage(raw.temporaryClosedNote),
      forceClosed: true,
    };
  }

  if (!isActiveRaw || signalType === "none") {
    return {
      type: "none",
      isActive: false,
      message: null,
      forceClosed: false,
    };
  }

  if (signalType === "vacation" || signalType === "temporary_closure") {
    return {
      type: signalType,
      isActive: true,
      message,
      forceClosed: true,
    };
  }

  return {
    type: "delay",
    isActive: true,
    message,
    forceClosed: false,
  };
}

function defaultLabelByType(type: MerchantOperationalSignalType): string | null {
  if (type === "vacation") return "De vacaciones";
  if (type === "temporary_closure") return "Cerrado temporalmente";
  if (type === "delay") return "Abre más tarde";
  return null;
}

export function resolveOperationalPublicState(
  signals?: OperationalSignals
): OperationalPublicState {
  const raw = (signals ?? {}) as Record<string, unknown>;
  const automaticIsOpenNow = raw.isOpenNow === true;
  const automaticScheduleLabel =
    typeof raw.todayScheduleLabel === "string"
      ? raw.todayScheduleLabel
      : "";
  const hasPharmacyDutyToday = raw.hasPharmacyDutyToday === true;
  const is24h = raw.is24h === true;
  const twentyFourHourStrikeCount =
    typeof raw.twentyFourHourStrikeCount === "number"
      ? Math.max(0, raw.twentyFourHourStrikeCount)
      : 0;
  const twentyFourHourCooldownUntil =
    raw.twentyFourHourCooldownUntil ?? null;
  const manual = sanitizeManualSignal(raw);

  const hasOperationalSignal = manual.isActive;
  const manualOverrideMode: ManualOverrideMode = !manual.isActive
    ? "none"
    : manual.forceClosed
      ? "force_closed"
      : "informational";
  const defaultLabel = defaultLabelByType(manual.type);
  const operationalStatusLabel = hasOperationalSignal
    ? (manual.message ?? defaultLabel)
    : null;

  const isOpenNow = manualOverrideMode === "force_closed"
    ? false
    : automaticIsOpenNow;
  const todayScheduleLabel = operationalStatusLabel ?? automaticScheduleLabel;

  return {
    hasOperationalSignal,
    operationalSignalType: hasOperationalSignal ? manual.type : "none",
    operationalSignalMessage: manual.message,
    manualOverrideMode,
    operationalStatusLabel,
    isOpenNow,
    todayScheduleLabel,
    hasPharmacyDutyToday,
    operationalSignals: {
      signalType: hasOperationalSignal ? manual.type : "none",
      isActive: hasOperationalSignal,
      message: manual.message,
      forceClosed: manual.forceClosed,
      hasOperationalSignal,
      manualOverrideMode,
      operationalStatusLabel,
      hasPharmacyDutyToday,
      is24h,
      twentyFourHourStrikeCount,
      twentyFourHourCooldownUntil,
      // Compatibilidad de lectura con clientes legacy.
      temporaryClosed:
        hasOperationalSignal &&
        (manual.type === "vacation" || manual.type === "temporary_closure"),
    },
  };
}

export function normalizeOperationalPublicStateForDiff(
  state: OperationalPublicState
): Record<string, unknown> {
  return {
    hasOperationalSignal: state.hasOperationalSignal,
    operationalSignalType: state.operationalSignalType,
    operationalSignalMessage: state.operationalSignalMessage ?? null,
    manualOverrideMode: state.manualOverrideMode,
    operationalStatusLabel: state.operationalStatusLabel ?? null,
    isOpenNow: state.isOpenNow,
    todayScheduleLabel: state.todayScheduleLabel,
    hasPharmacyDutyToday: state.hasPharmacyDutyToday,
    operationalSignals: state.operationalSignals,
  };
}
