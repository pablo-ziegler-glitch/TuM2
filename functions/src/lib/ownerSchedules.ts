import { FieldValue, getFirestore } from "firebase-admin/firestore";

type ScheduleMode = "closed" | "continuous" | "split";
type DayKey =
  | "monday"
  | "tuesday"
  | "wednesday"
  | "thursday"
  | "friday"
  | "saturday"
  | "sunday";

type TimeBlock = {
  open: string;
  close: string;
};

type EffectiveDay = {
  mode: ScheduleMode;
  blocks: TimeBlock[];
  source: "weekly" | "exception" | "closure";
};

const db = () => getFirestore();

const DAY_KEYS: DayKey[] = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

const WEEKLY_DAY_KEYS: DayKey[] = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];

function formatLocalDate(now: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const y = parts.find((p) => p.type === "year")?.value ?? "0000";
  const m = parts.find((p) => p.type === "month")?.value ?? "01";
  const d = parts.find((p) => p.type === "day")?.value ?? "01";
  return `${y}-${m}-${d}`;
}

function getLocalTimeParts(now: Date, timezone: string): {
  date: string;
  dayKey: DayKey;
  minuteOfDay: number;
} {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(now);

  const weekdayShort = parts.find((p) => p.type === "weekday")?.value ?? "Mon";
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
  const date = formatLocalDate(now, timezone);

  const dayKey = (() => {
    switch (weekdayShort) {
      case "Mon":
        return "monday";
      case "Tue":
        return "tuesday";
      case "Wed":
        return "wednesday";
      case "Thu":
        return "thursday";
      case "Fri":
        return "friday";
      case "Sat":
        return "saturday";
      default:
        return "sunday";
    }
  })();

  return {
    date,
    dayKey,
    minuteOfDay: (hour * 60) + minute,
  };
}

function parseBlocks(rawBlocks: unknown): TimeBlock[] {
  if (!Array.isArray(rawBlocks)) return [];
  return rawBlocks
    .map((entry) => {
      if (!entry || typeof entry !== "object") return null;
      const map = entry as Record<string, unknown>;
      const open = typeof map.open === "string" ? map.open : "";
      const close = typeof map.close === "string" ? map.close : "";
      if (!open || !close) return null;
      return { open, close };
    })
    .filter((entry): entry is TimeBlock => entry !== null)
    .sort((a, b) => toMinutes(a.open) - toMinutes(b.open));
}

function toMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(":").map(Number);
  return (h * 60) + m;
}

function effectiveMode(blocks: TimeBlock[]): ScheduleMode {
  if (blocks.length === 0) return "closed";
  if (blocks.length === 1) return "continuous";
  return "split";
}

function formatLabel(day: EffectiveDay): string {
  if (day.source === "closure") return "Cerrado temporalmente";
  if (day.blocks.length === 0) return "Cerrado hoy";
  if (day.blocks.length === 1) return `Hoy: ${day.blocks[0].open}–${day.blocks[0].close}`;
  return `Hoy: ${day.blocks[0].open}–${day.blocks[0].close} y ${day.blocks[1].open}–${day.blocks[1].close}`;
}

function nextOpeningForDay(blocks: TimeBlock[], minuteOfDay: number): string | null {
  for (const block of blocks) {
    if (toMinutes(block.open) > minuteOfDay) return block.open;
  }
  return null;
}

async function resolveDay(
  merchantId: string,
  dateKey: string,
  dayKey: DayKey,
  weeklySchedule: Record<string, unknown>,
): Promise<EffectiveDay> {
  const merchantRef = db().collection("merchants").doc(merchantId);
  const closureSnap = await merchantRef
    .collection("schedule_exceptions_ranges")
    .where("startDate", "<=", dateKey)
    .where("endDate", ">=", dateKey)
    .limit(1)
    .get();
  if (!closureSnap.empty) {
    return { mode: "closed", blocks: [], source: "closure" };
  }

  const exceptionSnap = await merchantRef
    .collection("schedule_exceptions")
    .doc(dateKey)
    .get();
  if (exceptionSnap.exists) {
    const exceptionData = exceptionSnap.data() as Record<string, unknown>;
    const exceptionType =
      typeof exceptionData.type === "string" ? exceptionData.type : "closed";
    if (exceptionType === "closed") {
      return { mode: "closed", blocks: [], source: "exception" };
    }
    const blocks = parseBlocks(exceptionData.blocks);
    return {
      mode: effectiveMode(blocks),
      blocks,
      source: "exception",
    };
  }

  const weeklyRaw = weeklySchedule[dayKey] as Record<string, unknown> | undefined;
  const mode =
    typeof weeklyRaw?.mode === "string"
      ? (weeklyRaw.mode as ScheduleMode)
      : "closed";
  const blocks = parseBlocks(weeklyRaw?.blocks);
  return {
    mode,
    blocks,
    source: "weekly",
  };
}

function computeOpenState(day: EffectiveDay, minuteOfDay: number): {
  isOpenNow: boolean;
  closesAt?: string;
  opensNextAt?: string;
} {
  for (const block of day.blocks) {
    const open = toMinutes(block.open);
    const close = toMinutes(block.close);
    if (minuteOfDay >= open && minuteOfDay < close) {
      return { isOpenNow: true, closesAt: block.close };
    }
  }
  return {
    isOpenNow: false,
    opensNextAt: nextOpeningForDay(day.blocks, minuteOfDay) ?? undefined,
  };
}

async function findNextWeeklyOpening(
  merchantId: string,
  timezone: string,
  now: Date,
  weeklySchedule: Record<string, unknown>,
): Promise<string | undefined> {
  for (let i = 1; i <= 7; i += 1) {
    const future = new Date(now.getTime() + (i * 24 * 60 * 60 * 1000));
    const parts = getLocalTimeParts(future, timezone);
    const resolved = await resolveDay(
      merchantId,
      parts.date,
      parts.dayKey,
      weeklySchedule,
    );
    if (resolved.blocks.length > 0) {
      return `${parts.date} ${resolved.blocks[0].open}`;
    }
  }
  return undefined;
}

export async function recomputeMerchantOperationalProjection(
  merchantId: string,
): Promise<void> {
  const merchantRef = db().collection("merchants").doc(merchantId);
  const weeklySnap = await merchantRef.collection("schedule_config").doc("weekly").get();

  if (!weeklySnap.exists) {
    const payload = {
      hasScheduleConfigured: false,
      isOpenNow: false,
      todayScheduleLabel: "Horarios no configurados",
      updatedAt: FieldValue.serverTimestamp(),
    };
    await Promise.all([
      db().doc(`merchant_operational_signals/${merchantId}`).set(payload, { merge: true }),
      db().doc(`merchant_public/${merchantId}`).set(
        {
          ...payload,
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      ),
    ]);
    return;
  }

  const weeklyData = weeklySnap.data() as Record<string, unknown>;
  const timezone = typeof weeklyData.timezone === "string"
    ? weeklyData.timezone
    : "America/Argentina/Buenos_Aires";
  const weeklySchedule =
    (weeklyData.weeklySchedule as Record<string, unknown> | undefined) ?? {};
  const now = new Date();
  const local = getLocalTimeParts(now, timezone);

  const effectiveToday = await resolveDay(
    merchantId,
    local.date,
    local.dayKey,
    weeklySchedule,
  );
  const status = computeOpenState(effectiveToday, local.minuteOfDay);
  const hasScheduleConfigured = WEEKLY_DAY_KEYS.some((dayKey) => {
    const dayMap = weeklySchedule[dayKey] as Record<string, unknown> | undefined;
    const blocks = parseBlocks(dayMap?.blocks);
    return blocks.length > 0;
  });
  const opensNextAt = status.opensNextAt ??
    await findNextWeeklyOpening(merchantId, timezone, now, weeklySchedule);

  const payload = {
    hasScheduleConfigured,
    isOpenNow: status.isOpenNow,
    todayScheduleLabel: formatLabel(effectiveToday),
    closesAt: status.closesAt ?? null,
    opensNextAt: opensNextAt ?? null,
    updatedAt: FieldValue.serverTimestamp(),
  };

  await Promise.all([
    db().doc(`merchant_operational_signals/${merchantId}`).set(payload, { merge: true }),
    db().doc(`merchant_public/${merchantId}`).set(
      {
        ...payload,
        syncedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    ),
  ]);
}

export function isSupportedDayKey(value: string): value is DayKey {
  return DAY_KEYS.includes(value as DayKey);
}
