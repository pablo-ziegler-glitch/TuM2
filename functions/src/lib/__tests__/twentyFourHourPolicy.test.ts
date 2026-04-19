import test from "node:test";
import assert from "node:assert/strict";
import { apply24hClosePolicy, canUse24hBadge } from "../twentyFourHourPolicy";

test("primer cierre con 24h activa aplica penalización de 24 horas", () => {
  const nowMs = Date.UTC(2026, 3, 18, 12, 0, 0);
  const result = apply24hClosePolicy({
    previousIsOpenNow: true,
    nextIsOpenNow: false,
    nowMs,
    state: {
      is24hEnabled: true,
      strikeCount: 0,
      cooldownUntilMs: null,
    },
  });

  assert.equal(result.removedBecauseClosed, true);
  assert.equal(result.next.is24hEnabled, false);
  assert.equal(result.next.strikeCount, 1);
  assert.equal(result.next.cooldownUntilMs, nowMs + 24 * 60 * 60 * 1000);
});

test("reincidencia aplica penalización de 7 días", () => {
  const nowMs = Date.UTC(2026, 3, 19, 9, 30, 0);
  const result = apply24hClosePolicy({
    previousIsOpenNow: true,
    nextIsOpenNow: false,
    nowMs,
    state: {
      is24hEnabled: true,
      strikeCount: 1,
      cooldownUntilMs: null,
    },
  });

  assert.equal(result.next.strikeCount, 2);
  assert.equal(result.next.cooldownUntilMs, nowMs + 7 * 24 * 60 * 60 * 1000);
});

test("si no hay cierre, no muta estado", () => {
  const nowMs = Date.UTC(2026, 3, 19, 9, 30, 0);
  const result = apply24hClosePolicy({
    previousIsOpenNow: false,
    nextIsOpenNow: false,
    nowMs,
    state: {
      is24hEnabled: true,
      strikeCount: 0,
      cooldownUntilMs: null,
    },
  });

  assert.equal(result.removedBecauseClosed, false);
  assert.equal(result.next.is24hEnabled, true);
  assert.equal(result.next.strikeCount, 0);
  assert.equal(result.next.cooldownUntilMs, null);
});

test("cooldown bloquea reutilización de 24h hasta expirar", () => {
  const nowMs = Date.UTC(2026, 3, 19, 9, 30, 0);
  const cooldownUntil = nowMs + 2 * 60 * 60 * 1000;

  assert.equal(
    canUse24hBadge(
      {
        is24hEnabled: true,
        strikeCount: 1,
        cooldownUntilMs: cooldownUntil,
      },
      nowMs
    ),
    false
  );
  assert.equal(
    canUse24hBadge(
      {
        is24hEnabled: true,
        strikeCount: 1,
        cooldownUntilMs: cooldownUntil,
      },
      cooldownUntil
    ),
    true
  );
});

