import test from 'node:test';
import assert from 'node:assert/strict';
import { validateAuditReport, normalizeAuditReport } from '../report-schema.mjs';

function validReport() {
  return {
    summary: 'Resumen técnico de auditoría incremental.',
    conclusion: 'APTO_CON_OBSERVACIONES',
    hasCritical: false,
    hasHigh: true,
    changedArea: ['functions', 'mobile'],
    filesReviewed: ['functions/src/index.ts'],
    findings: [
      {
        riskLevel: 'ALTO',
        component: 'functions',
        title: 'Falta limit en query',
        problem: 'Se detectó query amplia sin limit en un flujo sensible.',
        proposal: 'Agregar limit y paginación con cursor.',
        technicalRationale: 'Reduce lecturas y riesgo de scans costosos en Firestore.',
        costImpact: 'Alto en horas pico.',
        sideEffects: 'Requiere ajustar UX de paginación.',
        affectedFiles: ['functions/src/repo.ts'],
        approximateLines: ['20-45'],
        confidence: 0.89,
        requiresHumanReview: true,
      },
    ],
    quickWins: ['Agregar limit(20) en repositorio principal.'],
    productionChecklist: ['Validar índices compuestos para la nueva query.'],
    markdownReport: '## Resumen ejecutivo\n\nCon observaciones.',
  };
}

test('validateAuditReport acepta reporte válido', () => {
  const report = validReport();
  const result = validateAuditReport(report);
  assert.equal(result.ok, true);
});

test('validateAuditReport rechaza reporte inválido', () => {
  const report = validReport();
  report.findings[0].confidence = 2;
  const result = validateAuditReport(report);
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((error) => error.includes('confidence')));
});

test('normalizeAuditReport deduplica arrays', () => {
  const report = validReport();
  report.quickWins.push(report.quickWins[0]);
  report.filesReviewed.push('functions/src/index.ts');
  const normalized = normalizeAuditReport(report);
  assert.equal(normalized.quickWins.length, 1);
  assert.equal(normalized.filesReviewed.length, 1);
});
