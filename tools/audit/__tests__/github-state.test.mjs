import test from 'node:test';
import assert from 'node:assert/strict';
import { computeFindingFingerprint, shouldCreateIssue } from '../github-state.mjs';

test('computeFindingFingerprint es determinístico', () => {
  const finding = {
    riskLevel: 'ALTO',
    component: 'rules',
    title: 'Rules sin validación',
    problem: 'Falta validar ownership.',
    affectedFiles: ['firestore.rules', 'functions/src/auth.ts'],
  };
  const first = computeFindingFingerprint(finding);
  const second = computeFindingFingerprint({
    ...finding,
    affectedFiles: [...finding.affectedFiles].reverse(),
  });
  assert.equal(first, second);
});

test('shouldCreateIssue aplica política de severidad', () => {
  const base = {
    conclusion: 'APTO_CON_OBSERVACIONES',
    findings: [],
  };
  assert.equal(
    shouldCreateIssue({
      ...base,
      findings: [{ riskLevel: 'CRITICO' }],
    }),
    true,
  );
  assert.equal(
    shouldCreateIssue({
      ...base,
      findings: [{ riskLevel: 'ALTO' }, { riskLevel: 'ALTO' }],
    }),
    true,
  );
  assert.equal(
    shouldCreateIssue({
      ...base,
      conclusion: 'NO_APTO',
    }),
    true,
  );
  assert.equal(
    shouldCreateIssue({
      ...base,
      findings: [{ riskLevel: 'MEDIO' }],
    }),
    false,
  );
});
