import assert from "node:assert/strict";
import test from "node:test";
import {
  canDownloadSensitiveAttachment,
  canEvaluate,
  canResolve,
  canRevealSensitive,
  getAdminRoleFromClaims,
} from "../claims/adminPermissions";

test("getAdminRoleFromClaims detecta reviewer/senior/admin/super_admin", () => {
  assert.equal(
    getAdminRoleFromClaims({ role: "admin", claimsReviewLevel: "reviewer" }),
    "reviewer"
  );
  assert.equal(
    getAdminRoleFromClaims({
      role: "admin",
      claimsReviewLevel: "senior_reviewer",
    }),
    "senior_reviewer"
  );
  assert.equal(getAdminRoleFromClaims({ role: "admin" }), "admin");
  assert.equal(getAdminRoleFromClaims({ role: "super_admin" }), "super_admin");
  assert.equal(getAdminRoleFromClaims({ role: "customer" }), null);
});

test("canRevealSensitive deniega reviewer y permite senior+", () => {
  assert.equal(canRevealSensitive("reviewer"), false);
  assert.equal(canRevealSensitive("senior_reviewer"), true);
  assert.equal(canRevealSensitive("admin"), true);
  assert.equal(canRevealSensitive("super_admin"), true);
});

test("canEvaluate permite cualquier rol admin", () => {
  assert.equal(canEvaluate("reviewer"), true);
  assert.equal(canEvaluate("senior_reviewer"), true);
  assert.equal(canEvaluate("admin"), true);
  assert.equal(canEvaluate("super_admin"), true);
  assert.equal(canEvaluate(null), false);
});

test("senior approve permitido solo en caso simple seguro", () => {
  assert.equal(
    canResolve("senior_reviewer", "approve", {
      claimStatus: "under_review",
      hasConflict: false,
      hasDuplicate: false,
      isSensitiveCategory: false,
      riskLevel: "medium",
    }),
    true
  );

  assert.equal(
    canResolve("senior_reviewer", "approve", {
      claimStatus: "under_review",
      hasConflict: true,
      hasDuplicate: false,
      isSensitiveCategory: false,
      riskLevel: "medium",
    }),
    false
  );
  assert.equal(
    canResolve("senior_reviewer", "approve", {
      claimStatus: "under_review",
      hasConflict: false,
      hasDuplicate: false,
      isSensitiveCategory: true,
      riskLevel: "low",
    }),
    false
  );
});

test("reviewer no puede approve/reject/reveal ni download", () => {
  assert.equal(
    canResolve("reviewer", "approve", {
      claimStatus: "under_review",
      hasConflict: false,
      hasDuplicate: false,
      isSensitiveCategory: false,
      riskLevel: "low",
    }),
    false
  );
  assert.equal(
    canResolve("reviewer", "reject", {
      claimStatus: "under_review",
      hasConflict: false,
      hasDuplicate: false,
      isSensitiveCategory: false,
      riskLevel: "low",
    }),
    false
  );
  assert.equal(canRevealSensitive("reviewer"), false);
  assert.equal(canDownloadSensitiveAttachment("reviewer"), false);
});

test("download sensible solo admin/super_admin", () => {
  assert.equal(canDownloadSensitiveAttachment("senior_reviewer"), false);
  assert.equal(canDownloadSensitiveAttachment("admin"), true);
  assert.equal(canDownloadSensitiveAttachment("super_admin"), true);
});
