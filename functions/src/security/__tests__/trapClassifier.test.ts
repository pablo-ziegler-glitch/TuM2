import assert from "node:assert/strict";
import test from "node:test";

import { classifyTrapPath } from "../trapClassifier";

test("/.env clasifica como secret_probe + critical", () => {
  const result = classifyTrapPath("/.env");
  assert.equal(result.trapCategory, "secret_probe");
  assert.equal(result.severity, "critical");
});

test("/.env.production clasifica como secret_probe + critical", () => {
  const result = classifyTrapPath("/.env.production");
  assert.equal(result.trapCategory, "secret_probe");
  assert.equal(result.severity, "critical");
});

test("/wp-login.php clasifica como scanner_generic + warning", () => {
  const result = classifyTrapPath("/wp-login.php");
  assert.equal(result.trapCategory, "scanner_generic");
  assert.equal(result.severity, "warning");
});

test("/wp-admin/x clasifica como scanner_generic + warning", () => {
  const result = classifyTrapPath("/wp-admin/x");
  assert.equal(result.trapCategory, "scanner_generic");
  assert.equal(result.severity, "warning");
});

test("/api/admin/export-users clasifica como tum2_admin_probe + high", () => {
  const result = classifyTrapPath("/api/admin/export-users");
  assert.equal(result.trapCategory, "tum2_admin_probe");
  assert.equal(result.severity, "high");
});

test("/api/internal/merchant-dump clasifica como tum2_internal_probe + high", () => {
  const result = classifyTrapPath("/api/internal/merchant-dump");
  assert.equal(result.trapCategory, "tum2_internal_probe");
  assert.equal(result.severity, "high");
});

test("/api/claims/reveal-all clasifica como claim_probe + high", () => {
  const result = classifyTrapPath("/api/claims/reveal-all");
  assert.equal(result.trapCategory, "claim_probe");
  assert.equal(result.severity, "high");
});

test("/unknown clasifica como unknown_trap + warning", () => {
  const result = classifyTrapPath("/unknown");
  assert.equal(result.trapCategory, "unknown_trap");
  assert.equal(result.severity, "warning");
});
