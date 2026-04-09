import test from "node:test";
import assert from "node:assert/strict";
import {
  addDaysToDateKey,
  areRangesOverlapping,
  formatDateInArgentina,
  isPharmacyCategory,
  isValidDateKey,
} from "../pharmacyDuties";

test("isValidDateKey valida formato y calendario", () => {
  assert.equal(isValidDateKey("2026-02-28"), true);
  assert.equal(isValidDateKey("2026-02-30"), false);
  assert.equal(isValidDateKey("2026/02/28"), false);
});

test("addDaysToDateKey soporta cambios de mes y año", () => {
  assert.equal(addDaysToDateKey("2026-01-01", -1), "2025-12-31");
  assert.equal(addDaysToDateKey("2026-02-28", 1), "2026-03-01");
});

test("areRangesOverlapping detecta solapamientos", () => {
  const aStart = new Date("2026-05-12T08:00:00-03:00");
  const aEnd = new Date("2026-05-12T12:00:00-03:00");
  const bStart = new Date("2026-05-12T11:00:00-03:00");
  const bEnd = new Date("2026-05-12T13:00:00-03:00");
  const cStart = new Date("2026-05-12T12:00:00-03:00");
  const cEnd = new Date("2026-05-12T14:00:00-03:00");

  assert.equal(areRangesOverlapping(aStart, aEnd, bStart, bEnd), true);
  assert.equal(areRangesOverlapping(aStart, aEnd, cStart, cEnd), false);
});

test("formatDateInArgentina respeta zona operativa", () => {
  const date = new Date("2026-05-12T00:30:00-03:00");
  assert.equal(formatDateInArgentina(date), "2026-05-12");
});

test("isPharmacyCategory reconoce variantes canónicas", () => {
  assert.equal(isPharmacyCategory("pharmacy"), true);
  assert.equal(isPharmacyCategory("farmacia"), true);
  assert.equal(isPharmacyCategory("farmacia_veterinaria"), true);
  assert.equal(isPharmacyCategory("kiosco"), false);
});
