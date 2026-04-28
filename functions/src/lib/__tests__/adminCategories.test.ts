import { strict as assert } from "node:assert";
import test from "node:test";

import {
  canonicalCategoryToken,
  isCanonicalCategoryToken,
  uniqueCategoryTokens,
} from "../adminCategories";

test("canonicalCategoryToken normaliza sin alias legacy", () => {
  assert.equal(canonicalCategoryToken("  VeT "), "vet");
  assert.equal(canonicalCategoryToken("prepared_food"), "prepared_food");
});

test("isCanonicalCategoryToken valida formato canónico", () => {
  assert.equal(isCanonicalCategoryToken("prepared_food"), true);
  assert.equal(isCanonicalCategoryToken("fast_food_2"), true);
  assert.equal(isCanonicalCategoryToken("fast-food"), false);
  assert.equal(isCanonicalCategoryToken("con espacio"), false);
  assert.equal(isCanonicalCategoryToken("_leading"), false);
});

test("uniqueCategoryTokens remueve duplicados preservando orden", () => {
  assert.deepEqual(
    uniqueCategoryTokens(["veterinaria", "pet_shop", "veterinaria", "pet_shop", "vet"]),
    ["veterinaria", "pet_shop", "vet"]
  );
});
