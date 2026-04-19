export const RISK_LEVELS = ['CRITICO', 'ALTO', 'MEDIO', 'OPTIMIZACION'];
export const CONCLUSIONS = ['APTO', 'APTO_CON_OBSERVACIONES', 'NO_APTO'];

export const AUDIT_REPORT_JSON_SCHEMA = {
  type: 'object',
  required: [
    'summary',
    'conclusion',
    'hasCritical',
    'hasHigh',
    'changedArea',
    'filesReviewed',
    'findings',
    'quickWins',
    'productionChecklist',
    'markdownReport',
  ],
  additionalProperties: false,
  properties: {
    summary: { type: 'string', minLength: 10 },
    conclusion: { type: 'string', enum: CONCLUSIONS },
    hasCritical: { type: 'boolean' },
    hasHigh: { type: 'boolean' },
    changedArea: {
      type: 'array',
      minItems: 1,
      items: { type: 'string', minLength: 2 },
    },
    filesReviewed: {
      type: 'array',
      items: { type: 'string', minLength: 1 },
    },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: [
          'riskLevel',
          'component',
          'title',
          'problem',
          'proposal',
          'technicalRationale',
          'costImpact',
          'sideEffects',
          'affectedFiles',
          'approximateLines',
          'confidence',
          'requiresHumanReview',
        ],
        additionalProperties: false,
        properties: {
          riskLevel: { type: 'string', enum: RISK_LEVELS },
          component: { type: 'string', minLength: 2 },
          title: { type: 'string', minLength: 5 },
          problem: { type: 'string', minLength: 10 },
          proposal: { type: 'string', minLength: 10 },
          technicalRationale: { type: 'string', minLength: 10 },
          costImpact: { type: 'string', minLength: 2 },
          sideEffects: { type: 'string', minLength: 2 },
          affectedFiles: {
            type: 'array',
            items: { type: 'string', minLength: 1 },
          },
          approximateLines: {
            anyOf: [
              { type: 'array', items: { type: 'string', minLength: 1 } },
              { type: 'string', minLength: 1 },
            ],
          },
          confidence: { type: 'number', minimum: 0, maximum: 1 },
          requiresHumanReview: { type: 'boolean' },
        },
      },
    },
    quickWins: {
      type: 'array',
      items: { type: 'string', minLength: 4 },
    },
    productionChecklist: {
      type: 'array',
      items: { type: 'string', minLength: 4 },
    },
    markdownReport: { type: 'string', minLength: 20 },
  },
};

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function assert(condition, errors, message) {
  if (!condition) errors.push(message);
}

export function validateAuditReport(report) {
  const errors = [];
  if (!isObject(report)) {
    return { ok: false, errors: ['El reporte no es un objeto JSON.'] };
  }

  assert(typeof report.summary === 'string' && report.summary.length >= 10, errors, 'summary inválido');
  assert(CONCLUSIONS.includes(report.conclusion), errors, 'conclusion inválida');
  assert(typeof report.hasCritical === 'boolean', errors, 'hasCritical inválido');
  assert(typeof report.hasHigh === 'boolean', errors, 'hasHigh inválido');
  assert(Array.isArray(report.changedArea) && report.changedArea.length > 0, errors, 'changedArea inválido');
  assert(Array.isArray(report.filesReviewed), errors, 'filesReviewed inválido');
  assert(Array.isArray(report.findings), errors, 'findings inválido');
  assert(Array.isArray(report.quickWins), errors, 'quickWins inválido');
  assert(Array.isArray(report.productionChecklist), errors, 'productionChecklist inválido');
  assert(typeof report.markdownReport === 'string' && report.markdownReport.length >= 20, errors, 'markdownReport inválido');

  if (Array.isArray(report.findings)) {
    for (const [index, finding] of report.findings.entries()) {
      const prefix = `findings[${index}]`;
      assert(isObject(finding), errors, `${prefix} debe ser objeto`);
      if (!isObject(finding)) continue;
      assert(RISK_LEVELS.includes(finding.riskLevel), errors, `${prefix}.riskLevel inválido`);
      assert(typeof finding.component === 'string' && finding.component.length > 1, errors, `${prefix}.component inválido`);
      assert(typeof finding.title === 'string' && finding.title.length > 4, errors, `${prefix}.title inválido`);
      assert(typeof finding.problem === 'string' && finding.problem.length > 9, errors, `${prefix}.problem inválido`);
      assert(typeof finding.proposal === 'string' && finding.proposal.length > 9, errors, `${prefix}.proposal inválido`);
      assert(typeof finding.technicalRationale === 'string' && finding.technicalRationale.length > 9, errors, `${prefix}.technicalRationale inválido`);
      assert(typeof finding.costImpact === 'string' && finding.costImpact.length > 1, errors, `${prefix}.costImpact inválido`);
      assert(typeof finding.sideEffects === 'string' && finding.sideEffects.length > 1, errors, `${prefix}.sideEffects inválido`);
      assert(Array.isArray(finding.affectedFiles), errors, `${prefix}.affectedFiles inválido`);
      assert(
        Array.isArray(finding.approximateLines) || (typeof finding.approximateLines === 'string' && finding.approximateLines.length > 0),
        errors,
        `${prefix}.approximateLines inválido`,
      );
      assert(typeof finding.confidence === 'number' && finding.confidence >= 0 && finding.confidence <= 1, errors, `${prefix}.confidence inválido`);
      assert(typeof finding.requiresHumanReview === 'boolean', errors, `${prefix}.requiresHumanReview inválido`);
    }
  }

  return { ok: errors.length === 0, errors };
}

export function normalizeAuditReport(report) {
  const copy = structuredClone(report);
  copy.changedArea = [...new Set((copy.changedArea ?? []).map((v) => String(v).trim()).filter(Boolean))];
  copy.filesReviewed = [...new Set((copy.filesReviewed ?? []).map((v) => String(v).trim()).filter(Boolean))];
  copy.quickWins = [...new Set((copy.quickWins ?? []).map((v) => String(v).trim()).filter(Boolean))];
  copy.productionChecklist = [...new Set((copy.productionChecklist ?? []).map((v) => String(v).trim()).filter(Boolean))];
  copy.findings = (copy.findings ?? []).map((finding) => ({
    ...finding,
    affectedFiles: [...new Set((finding.affectedFiles ?? []).map((v) => String(v).trim()).filter(Boolean))],
    approximateLines: Array.isArray(finding.approximateLines)
      ? [...new Set(finding.approximateLines.map((v) => String(v).trim()).filter(Boolean))]
      : String(finding.approximateLines ?? '').trim(),
  }));
  return copy;
}
