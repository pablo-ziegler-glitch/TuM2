import assert from "node:assert/strict";
import test from "node:test";

import { detectHoneytoken } from "../honeytokens";

test("detecta honeytoken en path normalizado", () => {
  const result = detectHoneytoken({
    normalizedPath: "/api/internal/honey_claim_probe",
  });
  assert.equal(result.honeytokenDetected, true);
  assert.equal(result.honeytokenType, "claim_id");
});

test("detecta honeytoken en query/header/body", () => {
  const result = detectHoneytoken({
    normalizedPath: "/unknown",
    queryValues: ["tum2_honey_key_001"],
    headerValues: ["Bearer tum2_fake_admin_export_token"],
    bodyText: "payload honey_merchant_do_not_use",
  });
  assert.equal(result.honeytokenDetected, true);
  assert.ok(
    result.honeytokenType === "api_key" ||
      result.honeytokenType === "admin_token" ||
      result.honeytokenType === "merchant_id"
  );
});

test("no detecta cuando no hay token", () => {
  const result = detectHoneytoken({
    normalizedPath: "/api/admin/export-users",
    queryValues: ["abc"],
    headerValues: ["Mozilla/5.0"],
    bodyText: "plain text",
  });
  assert.equal(result.honeytokenDetected, false);
  assert.equal(result.honeytokenType, undefined);
});
