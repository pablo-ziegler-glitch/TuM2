import test from "node:test";
import assert from "node:assert/strict";
import { normalizeExternalCategory } from "../normalizeCategory";

test("normaliza categoria en espanol FARMACIA", () => {
  const category = normalizeExternalCategory("admin_import", "FARMACIA");
  assert.equal(category, "farmacia");
});

test("normaliza tipologia numerica de farmacias", () => {
  const category = normalizeExternalCategory("admin_import", "70");
  assert.equal(category, "farmacia");
});

test("normaliza tipos de google places", () => {
  const category = normalizeExternalCategory(
    "google_places",
    "pharmacy,point_of_interest,establishment"
  );
  assert.equal(category, "farmacia");
});

test("mantiene fallback cuando no encuentra mapeo", () => {
  const category = normalizeExternalCategory("admin_import", "categoria_rara");
  assert.equal(category, "comercio_general");
});
