import test from "node:test";
import assert from "node:assert/strict";
import {
  normalizeOperationalPublicStateForDiff,
  resolveOperationalPublicState,
} from "../operationalSignals";

test("vacation activa force_closed y cierra comercio", () => {
  const resolved = resolveOperationalPublicState({
    signalType: "vacation",
    isActive: true,
    message: null,
    forceClosed: true,
    isOpenNow: true,
    todayScheduleLabel: "Hoy: 09:00-18:00",
  });

  assert.equal(resolved.manualOverrideMode, "force_closed");
  assert.equal(resolved.isOpenNow, false);
  assert.equal(resolved.hasOperationalSignal, true);
  assert.equal(resolved.operationalSignalType, "vacation");
});

test("temporary_closure activa force_closed y cierra comercio", () => {
  const resolved = resolveOperationalPublicState({
    signalType: "temporary_closure",
    isActive: true,
    message: "Mantenimiento",
    forceClosed: true,
    isOpenNow: true,
  });

  assert.equal(resolved.manualOverrideMode, "force_closed");
  assert.equal(resolved.isOpenNow, false);
  assert.equal(resolved.operationalSignalType, "temporary_closure");
  assert.equal(resolved.operationalSignalMessage, "Mantenimiento");
});

test("delay es informativo y preserva isOpenNow automático", () => {
  const opened = resolveOperationalPublicState({
    signalType: "delay",
    isActive: true,
    forceClosed: false,
    isOpenNow: true,
  });
  const closed = resolveOperationalPublicState({
    signalType: "delay",
    isActive: true,
    forceClosed: false,
    isOpenNow: false,
  });

  assert.equal(opened.manualOverrideMode, "informational");
  assert.equal(opened.isOpenNow, true);
  assert.equal(closed.isOpenNow, false);
});

test("sin señal activa usa cálculo automático", () => {
  const resolved = resolveOperationalPublicState({
    signalType: "none",
    isActive: false,
    forceClosed: false,
    isOpenNow: true,
    todayScheduleLabel: "Hoy: 08:00-20:00",
  });

  assert.equal(resolved.hasOperationalSignal, false);
  assert.equal(resolved.manualOverrideMode, "none");
  assert.equal(resolved.isOpenNow, true);
  assert.equal(resolved.todayScheduleLabel, "Hoy: 08:00-20:00");
});

test("estado normalizado mantiene no-op diff cuando payload efectivo no cambia", () => {
  const before = resolveOperationalPublicState({
    signalType: "none",
    isActive: false,
    isOpenNow: true,
    todayScheduleLabel: "Hoy: 08:00-20:00",
  });
  const after = resolveOperationalPublicState({
    signalType: "none",
    isActive: false,
    isOpenNow: true,
    todayScheduleLabel: "Hoy: 08:00-20:00",
    // ruido extra que no cambia el estado efectivo
    message: "   ",
  });

  assert.deepEqual(
    normalizeOperationalPublicStateForDiff(before),
    normalizeOperationalPublicStateForDiff(after)
  );
});
