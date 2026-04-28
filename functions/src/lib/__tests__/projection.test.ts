import test from "node:test";
import assert from "node:assert/strict";
import { Timestamp } from "firebase-admin/firestore";
import {
  buildSearchKeywords,
  computePrimaryTrustBadge,
  computeMerchantPublicProjection,
  computeSortBoost,
  computeTrustBadges,
} from "../projection";
import { MerchantDoc, OperationalSignals } from "../types";

function buildMerchant(overrides: Partial<MerchantDoc> = {}): MerchantDoc {
  return {
    merchantId: "m-1",
    name: "Farmácia Ñandú",
    category: "veterinary_clinic",
    zone: "palermo",
    zoneId: "palermo",
    address: "Dr. Alvarez 123",
    verificationStatus: "verified",
    visibilityStatus: "visible",
    sourceType: "owner_created",
    ...overrides,
  };
}

test("buildSearchKeywords normaliza tildes y eñe", () => {
  const keywords = buildSearchKeywords(
    buildMerchant({ name: "Farmácia Ñandú" })
  );
  assert.ok(keywords.includes("farmacia"));
  assert.ok(keywords.includes("nandu"));
});

test("buildSearchKeywords contempla variantes de Dr/Dra/Prof", () => {
  const drKeywords = buildSearchKeywords(
    buildMerchant({ name: "Dr. Lopez" })
  );
  const draKeywords = buildSearchKeywords(
    buildMerchant({ name: "Dra. Gomez" })
  );
  const profKeywords = buildSearchKeywords(
    buildMerchant({ name: "Prof. Perez" })
  );

  assert.ok(drKeywords.includes("doctor"));
  assert.ok(draKeywords.includes("doctora"));
  assert.ok(profKeywords.includes("profesor"));
});

test("buildSearchKeywords soporta categoria compuesta", () => {
  const keywords = buildSearchKeywords(
    buildMerchant({ category: "convenience_store" })
  );

  assert.ok(keywords.includes("convenience"));
  assert.ok(keywords.includes("store"));
  assert.ok(keywords.includes("convenience store"));
  assert.ok(keywords.includes("kiosco"));
});

test("buildSearchKeywords indexa direccion sin numero", () => {
  const keywords = buildSearchKeywords(
    buildMerchant({ address: "Av. Santa Fe" })
  );

  assert.ok(keywords.includes("santa"));
  assert.ok(keywords.includes("santa fe"));
});

test("buildSearchKeywords sanitiza emojis y caracteres especiales", () => {
  const keywords = buildSearchKeywords(
    buildMerchant({ name: "Kiosco 💊 #1!!!" })
  );

  assert.ok(keywords.includes("kiosco"));
  assert.ok(!keywords.some((token) => token.includes("💊")));
  assert.ok(!keywords.some((token) => token.includes("#")));
});

test("buildSearchKeywords evita basura cuando name viene vacio", () => {
  const keywords = buildSearchKeywords(
    buildMerchant({ name: "   ", address: undefined, category: "" })
  );

  assert.equal(keywords.length, 0);
});

test("computeMerchantPublicProjection incluye searchKeywords y preserva campos", () => {
  const merchant = buildMerchant({
    name: "Dra. Núñez",
    category: "convenience_store",
  });

  const projection = computeMerchantPublicProjection(merchant);

  assert.equal(projection.merchantId, merchant.merchantId);
  assert.equal(projection.zoneId, merchant.zoneId);
  assert.equal(projection.categoryId, merchant.category);
  assert.ok(Array.isArray(projection.searchKeywords));
  assert.ok(projection.searchKeywords.length > 0);
  assert.ok(projection.searchKeywords.includes("doctora"));
  assert.ok(projection.searchKeywords.includes("kiosco"));
  assert.ok(Array.isArray(projection.badges));
});

function buildSignals(
  overrides: Partial<OperationalSignals> = {}
): OperationalSignals {
  return {
    hasPharmacyDutyToday: false,
    pharmacyDutyStatus: null,
    scheduleSummary: {
      timezone: "America/Argentina/Buenos_Aires",
      hasSchedule: true,
      todayWindows: [
        {
          opensAtLocalMinutes: 9 * 60,
          closesAtLocalMinutes: 18 * 60,
        },
      ],
      scheduleLastUpdatedAt: Timestamp.fromMillis(
        Date.now() - 10 * 24 * 60 * 60 * 1000
      ),
      lastVerifiedAt: Timestamp.fromMillis(
        Date.now() - 5 * 24 * 60 * 60 * 1000
      ),
    },
    ...overrides,
  };
}

test("trust badges: verified genera verified_merchant", () => {
  const badges = computeTrustBadges(
    buildMerchant({
      status: "active",
      verificationStatus: "verified",
      lastVerifiedAt: Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000),
    }),
    buildSignals()
  );
  assert.ok(badges.includes("verified_merchant"));
});

test("trust badges: validated genera validated_info", () => {
  const badges = computeTrustBadges(
    buildMerchant({ status: "active", verificationStatus: "validated" }),
    buildSignals()
  );
  assert.ok(badges.includes("validated_info"));
});

test("trust badges: claimed genera claimed_by_owner", () => {
  const badges = computeTrustBadges(
    buildMerchant({
      status: "active",
      verificationStatus: "claimed",
      ownerUserId: "owner-1",
    }),
    buildSignals()
  );
  assert.ok(badges.includes("claimed_by_owner"));
});

test("trust badges: community_suggested genera community_info", () => {
  const badges = computeTrustBadges(
    buildMerchant({
      status: "active",
      sourceType: "community_suggested",
      verificationStatus: "unverified",
    }),
    buildSignals()
  );
  assert.ok(badges.includes("community_info"));
});

test("trust badges: schedule_updated dentro de 30 dias", () => {
  const badges = computeTrustBadges(buildMerchant({ status: "active" }), buildSignals());
  assert.ok(badges.includes("schedule_updated"));
});

test("trust badges: schedule_updated viejo no se incluye", () => {
  const badges = computeTrustBadges(
    buildMerchant({ status: "active" }),
    buildSignals({
      scheduleSummary: {
        timezone: "America/Argentina/Buenos_Aires",
        hasSchedule: true,
        todayWindows: [],
        scheduleLastUpdatedAt: Timestamp.fromMillis(
          Date.now() - 50 * 24 * 60 * 60 * 1000
        ),
      },
    })
  );
  assert.equal(badges.includes("schedule_updated"), false);
});

test("trust badges: farmacia de turno publicada genera duty_loaded", () => {
  const badges = computeTrustBadges(
    buildMerchant({ status: "active", category: "pharmacy", categoryId: "pharmacy" }),
    buildSignals({
      hasPharmacyDutyToday: true,
      pharmacyDutyStatus: "published",
    })
  );
  assert.ok(badges.includes("duty_loaded"));
});

test("trust badges: schedule_verified con claim + horario verificado reciente", () => {
  const badges = computeTrustBadges(
    buildMerchant({
      status: "active",
      verificationStatus: "claimed",
      ownerUserId: "owner-1",
    }),
    buildSignals({
      scheduleSummary: {
        timezone: "America/Argentina/Buenos_Aires",
        hasSchedule: true,
        todayWindows: [],
        lastVerifiedAt: Timestamp.fromMillis(
          Date.now() - 20 * 24 * 60 * 60 * 1000
        ),
      },
    })
  );
  assert.ok(badges.includes("schedule_verified"));
});

test("primaryTrustBadge respeta prioridad", () => {
  const primary = computePrimaryTrustBadge([
    "visible_in_tum2",
    "schedule_updated",
    "verified_merchant",
  ]);
  assert.equal(primary, "verified_merchant");
});

test("sortBoost respeta orden esperado y tope", () => {
  const referential = computeSortBoost(
    buildMerchant({ verificationStatus: "referential" }),
    []
  );
  const verified = computeSortBoost(
    buildMerchant({ verificationStatus: "verified" }),
    ["schedule_verified", "schedule_updated", "duty_loaded"],
    { pharmacyContext: true }
  );

  assert.ok(verified > referential);
  assert.equal(verified, 120);
});
