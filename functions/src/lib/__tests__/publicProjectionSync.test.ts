import test from "node:test";
import assert from "node:assert/strict";
import {
  syncMerchantPublicProjection,
  SyncMerchantPublicProjectionInput,
} from "../publicProjectionSync";
import { MerchantDoc } from "../types";

class FakeDocSnapshot {
  constructor(private readonly value?: Record<string, unknown>) {}

  get exists(): boolean {
    return this.value !== undefined;
  }

  data(): Record<string, unknown> | undefined {
    if (!this.value) return undefined;
    return { ...this.value };
  }
}

class FakeFirestore {
  readonly docs = new Map<string, Record<string, unknown>>();
  readonly setCalls: Array<{
    path: string;
    data: Record<string, unknown>;
    merge: boolean;
  }> = [];
  readonly deleteCalls: string[] = [];

  doc(path: string): FakeDocRef {
    return new FakeDocRef(this, path);
  }
}

class FakeDocRef {
  constructor(
    private readonly firestore: FakeFirestore,
    private readonly path: string
  ) {}

  async get(): Promise<FakeDocSnapshot> {
    return new FakeDocSnapshot(this.firestore.docs.get(this.path));
  }

  async set(
    data: Record<string, unknown>,
    options?: { merge?: boolean }
  ): Promise<void> {
    const merge = options?.merge === true;
    const previous = this.firestore.docs.get(this.path);
    const next = { ...data };
    this.firestore.docs.set(
      this.path,
      merge ? { ...(previous ?? {}), ...next } : next
    );
    this.firestore.setCalls.push({ path: this.path, data: next, merge });
  }

  async delete(): Promise<void> {
    this.firestore.docs.delete(this.path);
    this.firestore.deleteCalls.push(this.path);
  }
}

function baseMerchant(overrides: Partial<MerchantDoc> = {}): MerchantDoc {
  return {
    merchantId: "m-1",
    name: "Farmacia Central",
    category: "pharmacy",
    categoryId: "pharmacy",
    zone: "zona-norte",
    zoneId: "zona-norte",
    verificationStatus: "verified",
    visibilityStatus: "visible",
    sourceType: "owner_created",
    ...overrides,
  };
}

function baseProjection(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    merchantId: "m-1",
    name: "Farmacia Central",
    category: "pharmacy",
    categoryId: "pharmacy",
    zone: "zona-norte",
    zoneId: "zona-norte",
    verificationStatus: "verified",
    visibilityStatus: "visible",
    sortBoost: 50,
    searchKeywords: ["farmacia", "central"],
    isOpenNow: true,
    hasOperationalSignal: false,
    operationalSignalType: "none",
    operationalSignalMessage: null,
    manualOverrideMode: "none",
    operationalStatusLabel: null,
    todayScheduleLabel: "08:00 - 20:00",
    hasPharmacyDutyToday: false,
    operationalSignals: {
      signalType: "none",
      isActive: false,
      message: null,
      forceClosed: false,
      hasOperationalSignal: false,
      manualOverrideMode: "none",
      operationalStatusLabel: null,
      hasPharmacyDutyToday: false,
      temporaryClosed: false,
    },
    ...overrides,
  };
}

async function runSync(options: {
  firestore: FakeFirestore;
  merchant?: MerchantDoc;
  projection: Record<string, unknown>;
  logger?: Pick<Console, "log">;
}): ReturnType<typeof syncMerchantPublicProjection> {
  const input: SyncMerchantPublicProjectionInput = {
    merchantId: "m-1",
    merchant: options.merchant ?? baseMerchant(),
    signals: null,
  };
  return syncMerchantPublicProjection(input, {
    firestore: options.firestore as unknown as FirebaseFirestore.Firestore,
    computeProjection: () => options.projection as ReturnType<
      typeof import("../projection").computeMerchantPublicProjection
    >,
    serverTimestamp: () => "__SERVER_TIMESTAMP__",
    logger: options.logger,
  });
}

test("sync inicial: escribe cuando merchant_public no existe", async () => {
  const firestore = new FakeFirestore();
  const result = await runSync({
    firestore,
    projection: baseProjection(),
  });

  assert.equal(result.publicWritePerformed, true);
  assert.equal(result.projectionWriteSkipped, false);
  assert.equal(firestore.setCalls.length, 1);
  assert.equal(firestore.setCalls[0]?.path, "merchant_public/m-1");
});

test("no-op puro: no escribe cuando el estado público equivalente no cambió", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set("merchant_public/m-1", {
    ...baseProjection(),
    syncedAt: { seconds: 1, nanos: 0 },
  });
  const logLines: string[] = [];

  const result = await runSync({
    firestore,
    projection: baseProjection(),
    logger: {
      log: (...args: unknown[]) => {
        logLines.push(args.map((arg) => String(arg)).join(" "));
      },
    },
  });

  assert.equal(result.publicWritePerformed, false);
  assert.equal(result.projectionWriteSkipped, true);
  assert.equal(result.reason, "no_changes");
  assert.equal(firestore.setCalls.length, 0);
  assert.ok(
    logLines.some((line) =>
      line.includes("[Sync] No-op: No hay cambios detectados para el comercio m-1")
    )
  );
});

test("cambio relevante en isOpenNow: escribe", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set("merchant_public/m-1", baseProjection({ isOpenNow: false }));

  const result = await runSync({
    firestore,
    projection: baseProjection({ isOpenNow: true }),
  });

  assert.equal(result.publicWritePerformed, true);
  assert.equal(result.projectionWriteSkipped, false);
  assert.equal(firestore.setCalls.length, 1);
});

test("cambio irrelevante solo en updatedAt: no escribe", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set(
    "merchant_public/m-1",
    baseProjection({ updatedAt: { seconds: 100 } })
  );

  const result = await runSync({
    firestore,
    projection: baseProjection({ updatedAt: { seconds: 200 } }),
  });

  assert.equal(result.publicWritePerformed, false);
  assert.equal(result.projectionWriteSkipped, true);
  assert.equal(firestore.setCalls.length, 0);
});

test("cambio de señal operativa: escribe", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set(
    "merchant_public/m-1",
    baseProjection({
      hasOperationalSignal: false,
      operationalSignalType: "none",
      operationalSignalMessage: null,
    })
  );

  const result = await runSync({
    firestore,
    projection: baseProjection({
      hasOperationalSignal: true,
      operationalSignalType: "temporary_closure",
      operationalSignalMessage: "Mantenimiento",
    }),
  });

  assert.equal(result.publicWritePerformed, true);
  assert.equal(result.projectionWriteSkipped, false);
  assert.equal(firestore.setCalls.length, 1);
});

test("cambio de visibilityStatus: escribe", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set(
    "merchant_public/m-1",
    baseProjection({ visibilityStatus: "visible" })
  );

  const result = await runSync({
    firestore,
    projection: baseProjection({ visibilityStatus: "hidden" }),
  });

  assert.equal(result.publicWritePerformed, true);
  assert.equal(result.projectionWriteSkipped, false);
  assert.equal(firestore.setCalls.length, 1);
});

test("cambio de status público: escribe", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set("merchant_public/m-1", baseProjection({ status: "open" }));

  const result = await runSync({
    firestore,
    projection: baseProjection({ status: "closed" }),
  });

  assert.equal(result.publicWritePerformed, true);
  assert.equal(result.projectionWriteSkipped, false);
  assert.equal(firestore.setCalls.length, 1);
});

test("merchant suppressed sin cambios: no-op sin write repetido", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set("merchant_public/m-1", {
    merchantId: "m-1",
    visibilityStatus: "suppressed",
  });

  const result = await runSync({
    firestore,
    merchant: baseMerchant({ visibilityStatus: "suppressed" }),
    projection: baseProjection(),
  });

  assert.equal(result.publicWritePerformed, false);
  assert.equal(result.projectionWriteSkipped, true);
  assert.equal(result.reason, "no_changes");
  assert.equal(firestore.setCalls.length, 0);
});

test("merchant missing: elimina merchant_public residual", async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set("merchant_public/m-1", baseProjection());

  const result = await syncMerchantPublicProjection(
    { merchantId: "m-1" },
    {
      firestore: firestore as unknown as FirebaseFirestore.Firestore,
      serverTimestamp: () => "__SERVER_TIMESTAMP__",
    }
  );

  assert.equal(result.publicWritePerformed, false);
  assert.equal(result.projectionWriteSkipped, true);
  assert.equal(result.reason, "merchant_missing");
  assert.equal(firestore.deleteCalls.includes("merchant_public/m-1"), true);
  assert.equal(firestore.docs.has("merchant_public/m-1"), false);
});
