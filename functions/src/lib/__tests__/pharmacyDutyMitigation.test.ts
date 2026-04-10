import test from "node:test";
import assert from "node:assert/strict";
import {
  deriveDutyPublicState,
  haversineDistanceKm,
  normalizeDutyStatus,
  roundDistance,
} from "../pharmacyDutyMitigation";

test("normalizeDutyStatus mapea legado a scheduled", () => {
  assert.equal(normalizeDutyStatus("draft"), "scheduled");
  assert.equal(normalizeDutyStatus("published"), "scheduled");
  assert.equal(normalizeDutyStatus("scheduled"), "scheduled");
});

test("deriveDutyPublicState degrada cuando hay incidente abierto", () => {
  const state = deriveDutyPublicState({
    status: "replacement_pending",
    confirmationStatus: "incident_reported",
    incidentOpen: true,
  });
  assert.equal(state.confidenceLevel, "low");
  assert.equal(state.publicStatusLabel, "cambio_operativo_en_curso");
});

test("deriveDutyPublicState marca alta confianza cuando está confirmada", () => {
  const state = deriveDutyPublicState({
    status: "scheduled",
    confirmationStatus: "confirmed",
    incidentOpen: false,
  });
  assert.equal(state.confidenceLevel, "high");
  assert.equal(state.publicStatusLabel, "guardia_confirmada");
});

test("haversineDistanceKm calcula distancia aproximada", () => {
  const km = haversineDistanceKm(-34.6037, -58.3816, -34.6097, -58.3842);
  assert.ok(km > 0.6 && km < 0.9);
  assert.equal(roundDistance(km).toFixed(2).length > 0, true);
});
