import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyDomain, shouldExcludePath, extractCollectionKeywords } from '../build-audit-context.mjs';

test('classifyDomain detecta dominio correcto', () => {
  assert.equal(classifyDomain('functions/src/index.ts'), 'functions');
  assert.equal(classifyDomain('mobile/lib/main.dart'), 'mobile');
  assert.equal(classifyDomain('web/lib/main.dart'), 'web');
  assert.equal(classifyDomain('schema/types/merchant.ts'), 'schema');
  assert.equal(classifyDomain('firestore.rules'), 'infra');
});

test('shouldExcludePath filtra sensibles y artefactos', () => {
  assert.equal(shouldExcludePath('.env.local'), true);
  assert.equal(shouldExcludePath('mobile/.dart_tool/state'), true);
  assert.equal(shouldExcludePath('google-services.json'), true);
  assert.equal(shouldExcludePath('functions/src/index.ts'), false);
});

test('extractCollectionKeywords prioriza colecciones/campos canónicos', () => {
  const text = `
    const col = 'merchant_public';
    const zoneId = payload.zoneId;
    const categoryId = payload.categoryId;
    const other = 'operational_signals';
  `;
  const keywords = extractCollectionKeywords(text);
  assert.ok(keywords.includes('merchant_public'));
  assert.ok(keywords.includes('zoneId'));
  assert.ok(keywords.includes('categoryId'));
  assert.ok(keywords.includes('operational_signals'));
});
