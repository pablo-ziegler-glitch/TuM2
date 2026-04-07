import test from "node:test";
import assert from "node:assert/strict";
import { HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminCallableAccess,
  shouldUpdateKeywords,
} from "../backfillKeywords";

test("assertAdminCallableAccess permite admin", () => {
  assert.doesNotThrow(() => {
    assertAdminCallableAccess({ token: { admin: true } });
  });
});

test("assertAdminCallableAccess rechaza no-admin", () => {
  assert.throws(
    () => assertAdminCallableAccess({ token: { admin: false } }),
    (error) =>
      error instanceof HttpsError && error.code === "permission-denied"
  );
});

test("assertAdminCallableAccess rechaza sin autenticacion", () => {
  assert.throws(
    () => assertAdminCallableAccess(null),
    (error) => error instanceof HttpsError && error.code === "unauthenticated"
  );
});

test("shouldUpdateKeywords detecta missing y cambios", () => {
  assert.equal(shouldUpdateKeywords(undefined, ["farmacia"]), true);
  assert.equal(shouldUpdateKeywords([], ["farmacia"]), true);
  assert.equal(shouldUpdateKeywords(["farmacia"], ["farmacia"]), false);
  assert.equal(shouldUpdateKeywords(["farmacia"], ["farmacia", "barrio"]), true);
  assert.equal(shouldUpdateKeywords(["farmacia"], ["veterinaria"]), true);
});
