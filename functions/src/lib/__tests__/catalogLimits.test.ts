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
    categoryLimits: { farmacia: 300 },
  });

  const result = resolveEffectiveCatalogLimit({
    merchant: {
      categoryId: "farmacia",
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
    categoryLimits: { farmacia: 300 },
  });

  const result = resolveEffectiveCatalogLimit({
    merchant: {
      categoryId: "farmacia",
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
      categoryId: "kiosco",
      catalogLimits: { productLimitOverride: null },
    },
    catalogConfig: config,
  });

  assert.equal(result.effectiveLimit, 100);
  assert.equal(result.limitSource, "global_default");
});

test("normalizeCatalogLimitsConfig descarta límites inválidos y preserva categorías permitidas", () => {
  const config = normalizeCatalogLimitsConfig({
    defaultProductLimit: 200,
    categoryLimits: {
      farmacia: 300,
      bakery: 999,
      confiteria: 120,
      grocery: 50.5,
      tire_shop: 500,
    },
  });

  assert.equal(config.defaultProductLimit, 200);
  assert.deepEqual(config.categoryLimits, {
    farmacia: 300,
    bakery: 999,
    confiteria: 120,
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

test("isAllowedCatalogCategoryId permite bakery/confitería y bloquea categoría prohibida legacy", () => {
  assert.equal(isAllowedCatalogCategoryId("farmacia"), true);
  assert.equal(isAllowedCatalogCategoryId("bakery"), true);
  assert.equal(isAllowedCatalogCategoryId("confiteria"), true);
  assert.equal(isAllowedCatalogCategoryId("bakery_confiteria"), false);
});
