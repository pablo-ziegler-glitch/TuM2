import assert from "node:assert/strict";
import test from "node:test";
import {
  computeUserAccessClaimsUpdate,
  type AccessRole,
} from "../accessClaims";

function run(params: {
  currentClaims: Record<string, unknown>;
  role: AccessRole;
  ownerPending: boolean;
  accessVersion?: number | null;
}) {
  return computeUserAccessClaimsUpdate({
    currentClaims: params.currentClaims,
    role: params.role,
    ownerPending: params.ownerPending,
    accessVersion: params.accessVersion,
  });
}

test("no-op cuando claims ya están en formato canónico", () => {
  const result = run({
    currentClaims: {
      role: "owner",
      owner_pending: false,
      admin: false,
      super_admin: false,
      access_version: 9,
      claims_version: 1,
      claims_updated_at: 1710000000,
      capabilities: ["claims.review"],
    },
    role: "owner",
    ownerPending: false,
    accessVersion: 9,
  });

  assert.equal(result.updated, false);
  assert.equal(result.previous.role, "owner");
  assert.equal(result.next.role, "owner");
  assert.deepEqual(result.nextClaimsWithoutTimestamp, {
    role: "owner",
    owner_pending: false,
    admin: false,
    super_admin: false,
    access_version: 9,
    claims_version: 1,
    capabilities: ["claims.review"],
  });
});

test("normaliza claims legacy y elimina merchantId/merchantIds/onboardingComplete", () => {
  const result = run({
    currentClaims: {
      role: "customer",
      owner_pending: false,
      merchantId: "m-1",
      merchantIds: ["m-1"],
      onboardingComplete: true,
      claimsReviewer: true,
    },
    role: "owner",
    ownerPending: true,
    accessVersion: 4,
  });

  assert.equal(result.updated, true);
  assert.equal(result.next.role, "owner");
  assert.equal(result.next.ownerPending, true);
  assert.deepEqual(result.nextClaimsWithoutTimestamp, {
    role: "owner",
    owner_pending: true,
    admin: false,
    super_admin: false,
    access_version: 4,
    claims_version: 1,
    claimsReviewer: true,
  });
});

test("roles administrativos setean flags admin/super_admin", () => {
  const adminResult = run({
    currentClaims: {},
    role: "admin",
    ownerPending: false,
    accessVersion: 1,
  });
  assert.equal(adminResult.next.admin, true);
  assert.equal(adminResult.next.superAdmin, false);

  const superAdminResult = run({
    currentClaims: {},
    role: "super_admin",
    ownerPending: false,
    accessVersion: 2,
  });
  assert.equal(superAdminResult.next.admin, true);
  assert.equal(superAdminResult.next.superAdmin, true);
});
