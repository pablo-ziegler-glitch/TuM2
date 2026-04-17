import fs from 'node:fs/promises';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { GoogleGenAI } from '@google/genai';
import { buildAuditContext } from './build-audit-context.mjs';
import {
  AUDIT_REPORT_JSON_SCHEMA,
  validateAuditReport,
  normalizeAuditReport,
  CONCLUSIONS,
} from './report-schema.mjs';
import {
  createGitHubClient,
  getOrCreateStateIssue,
  updateStateIssue,
  shouldCreateIssue,
  createOrUpdateAuditIssue,
  ensureLabel,
} from './github-state.mjs';

const execFileAsync = promisify(execFile);

function env(name, fallback = '') {
  return process.env[name] ?? fallback;
}

function log(event, payload = {}) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), event, ...payload }));
}

function toBool(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function sanitizeText(raw) {
  if (!raw) return '';
  return raw
    .replace(/AIza[0-9A-Za-z\-_]{20,}/g, '[REDACTED_KEY]')
    .replace(/(api[_-]?key|token|secret)\s*[:=]\s*["'][^"']+["']/gi, '$1:"[REDACTED]"')
    .replace(/[A-Za-z0-9_\-]{32,}\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}/g, '[REDACTED_JWT]');
}

async function runGit(args, { allowFailure = false } = {}) {
  try {
    const { stdout } = await execFileAsync('git', args, { maxBuffer: 16 * 1024 * 1024 });
    return stdout.trim();
  } catch (error) {
    if (allowFailure) return '';
    throw error;
  }
}

async function commitExists(sha) {
  if (!sha) return false;
  try {
    await execFileAsync('git', ['cat-file', '-e', `${sha}^{commit}`]);
    return true;
  } catch {
    return false;
  }
}

async function findEarliestReachableCommit(targetSha, maxCommits = 200) {
  const output = await runGit(
    ['rev-list', '--reverse', '--max-count', String(maxCommits), targetSha],
    { allowFailure: true },
  );
  if (!output) return '';
  const commits = output
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
  return commits[0] ?? '';
}

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function extractBalancedJsonValue(text) {
  if (!text) return null;
  let start = -1;
  const stack = [];
  let inString = false;
  let escaped = false;

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === '{' || ch === '[') {
      if (start === -1) start = i;
      stack.push(ch);
      continue;
    }
    if (ch === '}' || ch === ']') {
      if (stack.length === 0) continue;
      const open = stack[stack.length - 1];
      const closes = (open === '{' && ch === '}') || (open === '[' && ch === ']');
      if (!closes) {
        stack.length = 0;
        start = -1;
        continue;
      }
      stack.pop();
      if (stack.length === 0 && start !== -1) {
        const candidate = text.slice(start, i + 1).trim();
        const parsed = safeJsonParse(candidate);
        if (parsed) return parsed;
        start = -1;
      }
    }
  }
  return null;
}

function extractJson(text) {
  if (!text) return null;
  const direct = safeJsonParse(text);
  if (direct) return direct;
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i)?.[1] ?? text;
  const balanced = extractBalancedJsonValue(fenced);
  if (balanced) return balanced;
  const repaired = fenced.replace(/,\s*([}\]])/g, '$1').replace(/^\uFEFF/, '').trim();
  return extractBalancedJsonValue(repaired);
}

function collectGeminiTextCandidates(response) {
  const texts = [];
  if (response?.text) texts.push(response.text);
  const parts = response?.candidates?.flatMap((candidate) => candidate?.content?.parts ?? []) ?? [];
  for (const part of parts) {
    if (part?.text) texts.push(part.text);
  }
  return texts;
}

function extractJsonFromGeminiResponse(response) {
  for (const text of collectGeminiTextCandidates(response)) {
    const parsed = extractJson(text);
    if (parsed) return parsed;
  }
  return null;
}

function compactText(text, maxChars = 220) {
  return sanitizeText(String(text ?? '')).replace(/\s+/g, ' ').trim().slice(0, maxChars);
}

function describeGeminiResponse(response) {
  const candidateCount = response?.candidates?.length ?? 0;
  const finishReasons = [...new Set((response?.candidates ?? []).map((candidate) => candidate?.finishReason).filter(Boolean))];
  const finishMessages = (response?.candidates ?? []).map((candidate) => compactText(candidate?.finishMessage)).filter(Boolean).slice(0, 2);
  const texts = collectGeminiTextCandidates(response);
  const longestText = texts.reduce((best, current) => (current.length > best.length ? current : best), '');
  return {
    candidateCount,
    finishReasons,
    finishMessages,
    blockReason: response?.promptFeedback?.blockReason ?? null,
    textCount: texts.length,
    longestTextChars: longestText.length,
    preview: compactText(longestText),
  };
}

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`Timeout ${label}: ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildMasterPrompt(input) {
  const changedFilesSample = input.changedFiles.slice(0, 120);
  const relatedFilesSample = input.relatedFiles.slice(0, 80);
  return `
Sos TuM2 Auditor, un Principal Architect obsesivo por detectar fallas antes de producción.
Auditás cambios incrementales de código de TuM2 con foco en seguridad, costo Firebase, arquitectura, UX resiliente y deuda técnica.

Reglas canónicas obligatorias:
- Patrón dual-collection: merchants + merchant_public
- merchant_public solo se escribe desde Cloud Functions/Admin SDK
- Custom claims solo vía Admin SDK en Cloud Functions
- Contribuciones anónimas con ipHash, nunca IP cruda
- Campos canónicos: zoneId y categoryId
- Minimizar lecturas/writes/listeners/scans y evitar no-op writes

Deuda técnica conocida a considerar siempre:
- buildSearchKeywords() tipado pero no implementado en computeMerchantPublicProjection()
- ZoneSelectorSheet usa barrios hardcodeados
- getUserRole() en rules hace lectura extra a Firestore
- nightlyRefreshOpenStatuses no escala
- enforceAppCheck: false en callables admin
- comentarios JSON en firestore.indexes.json
- inconsistencia zone/category vs zoneId/categoryId

Inputs:
- branch: ${input.branch}
- baseSha: ${input.baseSha}
- targetSha: ${input.targetSha}
- changedFilesCount: ${input.changedFiles.length}
- changedFilesSample: ${JSON.stringify(changedFilesSample)}
- relatedFilesCount: ${input.relatedFiles.length}
- relatedFilesSample: ${JSON.stringify(relatedFilesSample)}
- changedAreas: ${JSON.stringify(input.changedAreas)}
- batchDomain: ${input.batchDomain}

Diff incremental:
${sanitizeText(input.diff)}

Archivos de contexto relacionados:
${input.files
  .map((file) => `\n### ${file.path}\n\`\`\`\n${sanitizeText(file.content)}\n\`\`\``)
  .join('\n')}

Objetivo de auditoría:
1) Arquitectura, 2) Frontend, 3) Backend, 4) Seguridad, 5) UX/Resiliencia, 6) Costos Firebase, 7) Efectos colaterales cross-layer.

Formato obligatorio de hallazgos por item:
riskLevel, component, title, problem, proposal, technicalRationale, costImpact, sideEffects, affectedFiles, approximateLines, confidence, requiresHumanReview.
Límites de salida: máximo 12 findings priorizados, quickWins <= 8, productionChecklist <= 8.

Conclusión final permitida: APTO | APTO_CON_OBSERVACIONES | NO_APTO.

Respondé exclusivamente JSON válido y estricto con el schema esperado.
`.trim();
}

function buildSynthesisPrompt({ branch, baseSha, targetSha, reports }) {
  return `
Unificá auditorías parciales por dominio en una sola auditoría final para TuM2.
No inventes hallazgos: consolida, deduplica y prioriza.

branch=${branch}
baseSha=${baseSha}
targetSha=${targetSha}

Reportes parciales:
${JSON.stringify(reports)}

Salida: JSON estricto con el mismo schema. Máximo 15 findings deduplicados.
`.trim();
}

async function callGeminiJson({ apiKey, model, prompt, retries = 3, timeoutMs = 75000 }) {
  const ai = new GoogleGenAI({ apiKey });
  let lastError;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const response = await withTimeout(
        ai.models.generateContent({
          model,
          contents: prompt,
          config: {
            temperature: 0,
            responseMimeType: 'application/json',
            responseJsonSchema: AUDIT_REPORT_JSON_SCHEMA,
            maxOutputTokens: 8192,
          },
        }),
        timeoutMs,
        'gemini.generateContent',
      );
      const parsed = extractJsonFromGeminiResponse(response);
      if (!parsed) {
        const details = describeGeminiResponse(response);
        throw new Error(`Gemini devolvió JSON inválido: ${JSON.stringify(details)}`);
      }
      return parsed;
    } catch (error) {
      lastError = error;
      if (attempt < retries) {
        await sleep(500 * 2 ** (attempt - 1));
      }
    }
  }
  throw lastError;
}

function mergeReportsLocal(reports) {
  const findings = [];
  const quickWins = [];
  const checklist = [];
  const filesReviewed = new Set();
  const changedArea = new Set();
  let hasCritical = false;
  let hasHigh = false;
  for (const report of reports) {
    report.filesReviewed.forEach((f) => filesReviewed.add(f));
    report.changedArea.forEach((a) => changedArea.add(a));
    report.quickWins.forEach((w) => quickWins.push(w));
    report.productionChecklist.forEach((c) => checklist.push(c));
    report.findings.forEach((f) => findings.push(f));
    hasCritical ||= report.hasCritical;
    hasHigh ||= report.hasHigh;
  }
  const conclusion = hasCritical || findings.filter((f) => f.riskLevel === 'ALTO').length >= 2 ? 'NO_APTO' : 'APTO_CON_OBSERVACIONES';
  return {
    summary: `Auditoría consolidada con ${findings.length} hallazgos.`,
    conclusion,
    hasCritical,
    hasHigh,
    changedArea: [...changedArea],
    filesReviewed: [...filesReviewed],
    findings,
    quickWins: [...new Set(quickWins)].slice(0, 12),
    productionChecklist: [...new Set(checklist)].slice(0, 12),
    markdownReport: `## Resumen ejecutivo\n\n${findings.length} hallazgos detectados.\n\n## Recomendación final\n\n${conclusion}`,
  };
}

function renderMarkdownReport({ report, context, metadata }) {
  const findingsMd = report.findings
    .map(
      (f, index) =>
        `${index + 1}. **[${f.riskLevel}] ${f.title}**\n` +
        `Componente: ${f.component}\n` +
        `Problema: ${f.problem}\n` +
        `Propuesta: ${f.proposal}\n` +
        `Impacto costo: ${f.costImpact}\n` +
        `Efectos colaterales: ${f.sideEffects}\n` +
        `Archivos: ${(f.affectedFiles ?? []).join(', ') || 'N/A'}\n` +
        `Líneas aproximadas: ${Array.isArray(f.approximateLines) ? f.approximateLines.join(', ') : f.approximateLines}`,
    )
    .join('\n\n');

  return [
    `# Scheduled Audit TuM2`,
    '',
    `- Fecha: ${new Date().toISOString()}`,
    `- Branch auditada: \`${metadata.branch}\``,
    `- Commit range: \`${metadata.baseSha}..${metadata.targetSha}\``,
    `- Modelo: \`${metadata.model}\``,
    `- Batches: ${context.batches.length}`,
    '',
    '## Resumen ejecutivo',
    report.summary,
    '',
    '## Alcance auditado',
    `Archivos cambiados (${context.changedFiles.length}): ${context.changedFiles.join(', ')}`,
    '',
    '## Hallazgos priorizados',
    findingsMd || 'Sin hallazgos.',
    '',
    '## Riesgos de producción',
    report.productionChecklist.map((item) => `- ${item}`).join('\n') || '- Sin checklist.',
    '',
    '## Quick wins',
    report.quickWins.map((item) => `- ${item}`).join('\n') || '- Sin quick wins.',
    '',
    '## Recomendación final',
    `**${report.conclusion}**`,
    '',
    '---',
    '',
    report.markdownReport,
  ].join('\n');
}

async function writeStepSummary(lines) {
  const summaryPath = env('GITHUB_STEP_SUMMARY');
  if (!summaryPath) return;
  await fs.appendFile(summaryPath, `${lines.join('\n')}\n`, 'utf8');
}

async function writeOutputs(outputs) {
  const outputPath = env('GITHUB_OUTPUT');
  if (!outputPath) return;
  const payload = Object.entries(outputs)
    .map(([key, value]) => `${key}=${String(value)}`)
    .join('\n');
  await fs.appendFile(outputPath, `${payload}\n`, 'utf8');
}

function assertConclusion(value) {
  return CONCLUSIONS.includes(value) ? value : 'APTO_CON_OBSERVACIONES';
}

async function main() {
  const branch = env('AUDIT_TARGET_BRANCH', 'develop');
  const model = env('AUDIT_MODEL', 'gemini-2.5-flash');
  const maxFiles = Number(env('AUDIT_MAX_FILES', '25'));
  const maxInputChars = Number(env('AUDIT_MAX_INPUT_CHARS', '220000'));
  const maxFullAuditFiles = Number(env('AUDIT_MAX_FULL_FILES', '180'));
  const forceFullAudit = toBool(env('AUDIT_FORCE_FULL'), false);
  const apiKey = env('GEMINI_API_KEY');
  const repository = env('GITHUB_REPOSITORY');
  const runUrl = `${env('GITHUB_SERVER_URL', 'https://github.com')}/${repository}/actions/runs/${env('GITHUB_RUN_ID', 'local')}`;

  log('audit.start', { branch, model, maxFiles, maxInputChars, maxFullAuditFiles, forceFullAudit });

  await runGit(['fetch', 'origin', branch, '--depth=200'], { allowFailure: true });
  const targetSha = await runGit(['rev-parse', `origin/${branch}`]);

  const ghClient = await createGitHubClient({
    token: env('GITHUB_TOKEN'),
    repository,
  });

  let stateIssue = null;
  let previousState = null;
  if (ghClient) {
    await ensureLabel(ghClient, 'scheduled-audit-state');
    stateIssue = await getOrCreateStateIssue(ghClient, { branch });
    previousState = stateIssue.state;
  }

  let baseSha = previousState?.lastAuditedSha ?? '';
  const hasValidBase = (await commitExists(baseSha)) && !forceFullAudit;
  if (!hasValidBase) {
    const earliestReachable = await findEarliestReachableCommit(targetSha, 200);
    if (earliestReachable) {
      const earliestParent = await runGit(['rev-parse', `${earliestReachable}^`], {
        allowFailure: true,
      });
      // Preferir el parent para incluir también el commit más viejo disponible.
      baseSha = earliestParent || earliestReachable;
      log('audit.base_fallback_window', {
        reason: forceFullAudit ? 'forced_full' : 'missing_or_invalid_state_sha',
        earliestReachable,
        fallbackBase: baseSha,
      });
    }
  }
  if (!baseSha) {
    baseSha = targetSha;
  }

  if (baseSha === targetSha) {
    await writeStepSummary([
      '## Scheduled Audit',
      '',
      `Sin cambios para auditar en \`${branch}\` (sha \`${targetSha.slice(0, 12)}\`).`,
    ]);
    await writeOutputs({ audited: 'false', skipped_reason: 'no_changes' });
    return;
  }

  const context = await buildAuditContext({
    baseSha,
    targetSha,
    maxFiles,
    maxInputChars,
    forceFullAudit,
    maxFullAuditFiles,
  });

  if (!context.hasChanges) {
    await writeStepSummary([
      '## Scheduled Audit',
      '',
      `Sin diff incremental entre \`${baseSha.slice(0, 12)}\` y \`${targetSha.slice(0, 12)}\`.`,
      'No se invocó Gemini para minimizar costo.',
    ]);
    await writeOutputs({ audited: 'false', skipped_reason: 'empty_diff' });
    return;
  }

  if (!apiKey) {
    throw new Error('Falta GEMINI_API_KEY');
  }

  const perBatchReports = [];
  let geminiFailed = false;
  let geminiFailureReason = '';

  for (const batch of context.batches) {
    const prompt = buildMasterPrompt({
      branch,
      baseSha,
      targetSha,
      changedFiles: context.changedFiles,
      relatedFiles: context.relatedFiles,
      changedAreas: context.changedAreas,
      batchDomain: batch.domain,
      diff: batch.diff,
      files: batch.files,
    });

    try {
      const raw = await callGeminiJson({ apiKey, model, prompt });
      const normalized = normalizeAuditReport(raw);
      const validation = validateAuditReport(normalized);
      if (!validation.ok) {
        throw new Error(`JSON inválido para batch ${batch.domain}: ${validation.errors.join('; ')}`);
      }
      perBatchReports.push(normalized);
    } catch (error) {
      geminiFailed = true;
      geminiFailureReason = String(error.message ?? error);
      log('audit.gemini_error', { domain: batch.domain, error: geminiFailureReason });
      break;
    }
  }

  let finalReport;
  if (geminiFailed) {
    finalReport = {
      summary: 'La auditoría incremental no pudo completarse por error de Gemini.',
      conclusion: 'APTO_CON_OBSERVACIONES',
      hasCritical: false,
      hasHigh: false,
      changedArea: context.changedAreas.length > 0 ? context.changedAreas : ['infra'],
      filesReviewed: context.changedFiles,
      findings: [
        {
          riskLevel: 'MEDIO',
          component: 'audit-pipeline',
          title: 'Fallo no bloqueante del motor de auditoría',
          problem: geminiFailureReason.slice(0, 500),
          proposal: 'Reintentar manualmente workflow_dispatch y revisar cuota/latencia de Gemini.',
          technicalRationale: 'Se evita estado inconsistente: no se actualiza lastAuditedSha hasta auditoría correcta.',
          costImpact: 'No impacta Firestore; solo costo de pipeline de CI.',
          sideEffects: 'Puede repetirse la auditoría en próxima corrida programada.',
          affectedFiles: ['tools/audit/run-scheduled-audit.mjs'],
          approximateLines: ['1-999'],
          confidence: 0.95,
          requiresHumanReview: true,
        },
      ],
      quickWins: ['Configurar alerta de tasa de fallos de workflow scheduled_audit.'],
      productionChecklist: ['Ejecutar workflow_dispatch con force_full=false para revalidar.'],
      markdownReport: `## Error de auditoría\n\n${geminiFailureReason}`,
    };
  } else if (perBatchReports.length > 1) {
    try {
      const synthPrompt = buildSynthesisPrompt({
        branch,
        baseSha,
        targetSha,
        reports: perBatchReports,
      });
      const synthRaw = await callGeminiJson({ apiKey, model, prompt: synthPrompt, retries: 2 });
      finalReport = normalizeAuditReport(synthRaw);
      const validation = validateAuditReport(finalReport);
      if (!validation.ok) {
        throw new Error(validation.errors.join('; '));
      }
    } catch {
      finalReport = mergeReportsLocal(perBatchReports);
    }
  } else {
    finalReport = perBatchReports[0];
  }

  finalReport.conclusion = assertConclusion(finalReport.conclusion);
  finalReport.hasCritical = finalReport.findings.some((f) => f.riskLevel === 'CRITICO');
  finalReport.hasHigh = finalReport.findings.some((f) => f.riskLevel === 'ALTO');
  finalReport.filesReviewed = [...new Set(finalReport.filesReviewed)];
  finalReport.changedArea = [...new Set(finalReport.changedArea)];

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const artifactName = `scheduled-audit-${branch}-${timestamp}`;
  const artifactDir = path.resolve('artifacts/audits');
  const artifactPath = path.join(artifactDir, `audit-${timestamp}.md`);
  await fs.mkdir(artifactDir, { recursive: true });
  const markdown = renderMarkdownReport({
    report: finalReport,
    context,
    metadata: { branch, baseSha, targetSha, model },
  });
  await fs.writeFile(artifactPath, markdown, 'utf8');

  let issueResult = null;
  let issuePublicationFailed = false;
  const issueRequiredByPolicy = shouldCreateIssue(finalReport);
  if (ghClient && shouldCreateIssue(finalReport)) {
    try {
      issueResult = await createOrUpdateAuditIssue(ghClient, {
        report: finalReport,
        range: { baseSha, targetSha },
        runUrl,
        artifactName,
        branch,
      });
    } catch (error) {
      issuePublicationFailed = true;
      log('audit.issue_error', { error: String(error.message ?? error) });
    }
  } else if (issueRequiredByPolicy) {
    issuePublicationFailed = true;
    log('audit.issue_error', {
      error: 'Issue requerida por política, pero no hay cliente GitHub disponible.',
    });
  }

  if (ghClient && stateIssue && !geminiFailed && !issuePublicationFailed) {
    await updateStateIssue(ghClient, {
      issueNumber: stateIssue.issueNumber,
      branch,
      newState: {
        branch,
        lastAuditedSha: targetSha,
        lastAuditAt: new Date().toISOString(),
        lastReportConclusion: finalReport.conclusion,
        lastReportArtifactName: artifactName,
      },
    });
  }

  await writeStepSummary([
    '## Scheduled Audit',
    '',
    `Conclusión: **${finalReport.conclusion}**`,
    `Branch: \`${branch}\``,
    `Commit range: \`${baseSha.slice(0, 12)}..${targetSha.slice(0, 12)}\``,
    `Archivos cambiados: ${context.changedFiles.length}`,
    `Hallazgos: ${finalReport.findings.length} (Críticos: ${finalReport.findings.filter((f) => f.riskLevel === 'CRITICO').length}, Altos: ${finalReport.findings.filter((f) => f.riskLevel === 'ALTO').length})`,
    issueResult ? `Issue: ${issueResult.action} #${issueResult.issueNumber}` : 'Issue: no requerido por política',
    issuePublicationFailed ? 'Issue: ERROR de publicación (state no actualizado)' : 'Issue publish: OK',
    geminiFailed ? `Gemini: fallo no bloqueante (${geminiFailureReason})` : 'Gemini: OK',
  ]);

  await writeOutputs({
    audited: 'true',
    artifact_path: artifactPath,
    artifact_name: artifactName,
    conclusion: finalReport.conclusion,
    has_critical: finalReport.hasCritical,
    has_high: finalReport.hasHigh,
  });

  log('audit.finish', {
    conclusion: finalReport.conclusion,
    findings: finalReport.findings.length,
    artifactPath,
    issue: issueResult?.issueNumber ?? null,
  });
}

main().catch(async (error) => {
  log('audit.fatal', { error: String(error?.stack ?? error) });
  await writeStepSummary(['## Scheduled Audit', '', `Error fatal: ${String(error?.message ?? error)}`]);
  await writeOutputs({ audited: 'false', skipped_reason: 'fatal_error' });
  process.exitCode = 1;
});
