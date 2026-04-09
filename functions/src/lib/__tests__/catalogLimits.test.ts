import { strict as assert } from "node:assert";
import test from "node:test";

import {
  isAllowedCatalogCategoryId,
  normalizeCatalogLimitsConfig,
  resolveActiveProductCount,
  resolveEffectiveCatalogLimit,
} from "../catalogLimits";

test("resolveEffectiveCatalogLimit prioriza merchant override", () => {
  const config = normalizeCatalogLimitsConfig({
    defaultProductLimit: 100,
    categoryLimits: { pharmacy: 300 },
  });

  const result = resolveEffectiveCatalogLimit({
    merchant: {
      categoryId: "pharmacy",
      catalogLimits: { productLimitOverride: 500 },
    },
    catalogConfig: config,
  });

  assert.equal(result.effectiveLimit, 500);
  assert.equal(result.limitSource, "merchant_override");
});

test("resolveEffectiveCatalogLimit usa límite por categoría cuando no hay override", () => {
  const config = normalizeCatalogLimitsConfig({
    defaultProductLimit: 100,
    categoryLimits: { pharmacy: 300 },
  });

  const result = resolveEffectiveCatalogLimit({
    merchant: {
      categoryId: "pharmacy",
      catalogLimits: { productLimitOverride: null },
    },
    catalogConfig: config,
  });

  assert.equal(result.effectiveLimit, 300);
  assert.equal(result.limitSource, "category_override");
});

test("resolveEffectiveCatalogLimit usa global por defecto", () => {
  const config = normalizeCatalogLimitsConfig({
    defaultProductLimit: 100,
    categoryLimits: {},
  });

  const result = resolveEffectiveCatalogLimit({
    merchant: {
      categoryId: "kiosk",
      catalogLimits: { productLimitOverride: null },
    },
    catalogConfig: config,
  });

  assert.equal(result.effectiveLimit, 100);
  assert.equal(result.limitSource, "global_default");
});

test("normalizeCatalogLimitsConfig descarta categorías inválidas y límites no enteros", () => {
  const config = normalizeCatalogLimitsConfig({
    defaultProductLimit: 200,
    categoryLimits: {
      pharmacy: 300,
      bakery: 999,
      grocery: 50.5,
      tire_shop: 500,
    },
  });

  assert.equal(config.defaultProductLimit, 200);
  assert.deepEqual(config.categoryLimits, {
    pharmacy: 300,
    tire_shop: 500,
  });
});

test("resolveActiveProductCount retorna 0 con valores inválidos", () => {
  assert.equal(resolveActiveProductCount({}), 0);
  assert.equal(
    resolveActiveProductCount({ catalogStats: { activeProductCount: -3 } }),
    0
  );
  assert.equal(
    resolveActiveProductCount({ catalogStats: { activeProductCount: 87 } }),
    87
  );
});

test("isAllowedCatalogCategoryId bloquea bakery/confitería", () => {
  assert.equal(isAllowedCatalogCategoryId("pharmacy"), true);
  assert.equal(isAllowedCatalogCategoryId("bakery"), false);
  assert.equal(isAllowedCatalogCategoryId("confiteria"), false);
});
