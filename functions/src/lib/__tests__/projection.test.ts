import test from "node:test";
import assert from "node:assert/strict";
import {
  buildSearchKeywords,
  computeMerchantPublicProjection,
} from "../projection";
import { MerchantDoc } from "../types";

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
});
