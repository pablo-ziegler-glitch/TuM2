import crypto from 'node:crypto';

const API_BASE = 'https://api.github.com';
const STATE_MARKER_START = '<!-- audit-state:start -->';
const STATE_MARKER_END = '<!-- audit-state:end -->';

function nowIso() {
  return new Date().toISOString();
}

function asJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function splitRepo(fullRepo) {
  const [owner, repo] = String(fullRepo || '').split('/');
  if (!owner || !repo) throw new Error(`GITHUB_REPOSITORY inválido: ${fullRepo}`);
  return { owner, repo };
}

function buildHeaders(token) {
  return {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'tum2-scheduled-audit',
  };
}

export function computeFindingFingerprint(finding) {
  const stable = JSON.stringify({
    riskLevel: finding.riskLevel ?? '',
    component: finding.component ?? '',
    title: finding.title ?? '',
    problem: finding.problem ?? '',
    affectedFiles: [...(finding.affectedFiles ?? [])].sort(),
  });
  return crypto.createHash('sha256').update(stable).digest('hex').slice(0, 24);
}

export function shouldCreateIssue(report) {
  const criticalCount = report.findings.filter((f) => f.riskLevel === 'CRITICO').length;
  const highCount = report.findings.filter((f) => f.riskLevel === 'ALTO').length;
  return criticalCount >= 1 || highCount >= 2 || report.conclusion === 'NO_APTO';
}

function extractStateFromText(text) {
  if (!text?.includes(STATE_MARKER_START) || !text?.includes(STATE_MARKER_END)) return null;
  const start = text.indexOf(STATE_MARKER_START) + STATE_MARKER_START.length;
  const end = text.indexOf(STATE_MARKER_END);
  if (start <= 0 || end <= start) return null;
  return asJson(text.slice(start, end).trim());
}

function buildStateBody(branch, state) {
  return [
    `Estado operativo de auditoría incremental para \`${branch}\`.`,
    '',
    STATE_MARKER_START,
    JSON.stringify(state),
    STATE_MARKER_END,
    '',
    `Última actualización: ${nowIso()}`,
  ].join('\n');
}

export async function createGitHubClient({ token, repository }) {
  if (!token || !repository) return null;
  const { owner, repo } = splitRepo(repository);
  const headers = buildHeaders(token);

  async function request(path, options = {}) {
    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: { ...headers, ...(options.headers ?? {}) },
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`GitHub API ${response.status} ${path}: ${body.slice(0, 300)}`);
    }
    if (response.status === 204) return null;
    return response.json();
  }

  return { owner, repo, request };
}

export async function ensureLabel(client, label) {
  try {
    await client.request(`/repos/${client.owner}/${client.repo}/labels/${encodeURIComponent(label)}`);
  } catch {
    await client.request(`/repos/${client.owner}/${client.repo}/labels`, {
      method: 'POST',
      body: JSON.stringify({
        name: label,
        color: '1D76DB',
        description: 'Etiqueta generada por auditoría programada',
      }),
    });
  }
}

export async function getOrCreateStateIssue(client, { branch }) {
  const title = `[audit-state] ${branch}`;
  const issues = await client.request(`/repos/${client.owner}/${client.repo}/issues?state=all&per_page=100`);
  let issue = issues.find((item) => item.title === title);
  if (!issue) {
    issue = await client.request(`/repos/${client.owner}/${client.repo}/issues`, {
      method: 'POST',
      body: JSON.stringify({
        title,
        body: buildStateBody(branch, {
          branch,
          lastAuditedSha: null,
          lastAuditAt: null,
          lastReportConclusion: null,
          lastReportArtifactName: null,
        }),
        labels: ['scheduled-audit-state'],
      }),
    });
  }

  const issueBodyState = extractStateFromText(issue.body ?? '');
  const comments = await client.request(
    `/repos/${client.owner}/${client.repo}/issues/${issue.number}/comments?per_page=20`,
  );
  const latestCommentState = comments
    .slice()
    .reverse()
    .map((comment) => extractStateFromText(comment.body ?? ''))
    .find(Boolean);

  return {
    issueNumber: issue.number,
    issueUrl: issue.html_url,
    state: latestCommentState ?? issueBodyState,
  };
}

export async function updateStateIssue(client, { issueNumber, branch, newState }) {
  const body = buildStateBody(branch, newState);
  await client.request(`/repos/${client.owner}/${client.repo}/issues/${issueNumber}`, {
    method: 'PATCH',
    body: JSON.stringify({ body }),
  });
}

function extractAreaLabels(files) {
  const labels = new Set();
  for (const file of files) {
    if (file.startsWith('functions/')) labels.add('area:functions');
    if (file.startsWith('mobile/')) labels.add('area:mobile');
    if (file.startsWith('web/')) labels.add('area:web');
    if (file.endsWith('.rules')) labels.add('area:rules');
    if (file.startsWith('.github/workflows/')) labels.add('area:infra');
    if (file.startsWith('schema/')) labels.add('area:schema');
  }
  return [...labels];
}

function formatIssueBody({ report, range, runUrl, artifactName, fingerprints }) {
  const topFindings = report.findings
    .filter((finding) => finding.riskLevel === 'CRITICO' || finding.riskLevel === 'ALTO')
    .slice(0, 6)
    .map((finding) => `- [${finding.riskLevel}] ${finding.title} (${finding.component})`)
    .join('\n');
  return [
    `Conclusión: **${report.conclusion}**`,
    '',
    report.summary,
    '',
    'Top hallazgos:',
    topFindings || '- Sin hallazgos críticos/altos.',
    '',
    `Commit range: \`${range.baseSha}..${range.targetSha}\``,
    `Workflow run: ${runUrl}`,
    `Artifact: \`${artifactName}\``,
    `Fingerprints: ${fingerprints.map((f) => `\`${f}\``).join(', ') || 'N/A'}`,
  ].join('\n');
}

export async function createOrUpdateAuditIssue(client, payload) {
  const { report, range, runUrl, artifactName, branch } = payload;
  const fingerprints = report.findings.map(computeFindingFingerprint);
  const uniqueFingerprints = [...new Set(fingerprints)];
  const severeFindings = report.findings.filter((finding) => finding.riskLevel === 'CRITICO' || finding.riskLevel === 'ALTO');
  const labels = ['scheduled-audit', ...extractAreaLabels(report.filesReviewed)];
  if (report.findings.some((f) => f.riskLevel === 'CRITICO')) labels.push('severity:critical');
  if (report.findings.some((f) => f.riskLevel === 'ALTO')) labels.push('severity:high');

  const existing = [];
  for (const fingerprint of uniqueFingerprints) {
    const search = await client.request(
      `/search/issues?q=${encodeURIComponent(`repo:${client.owner}/${client.repo} is:issue is:open "fingerprint:${fingerprint}"`)}`,
    );
    if (Array.isArray(search.items) && search.items.length > 0) existing.push(search.items[0]);
  }
  const targetIssue = existing[0];
  const timestamp = new Date().toISOString().slice(0, 16).replace('T', ' ');
  const summaryBody = formatIssueBody({ report, range, runUrl, artifactName, fingerprints: uniqueFingerprints });
  const fingerprintsLine = `\n\n${uniqueFingerprints.map((fp) => `fingerprint:${fp}`).join('\n')}`;

  for (const label of labels) {
    await ensureLabel(client, label);
  }

  if (targetIssue) {
    await client.request(`/repos/${client.owner}/${client.repo}/issues/${targetIssue.number}/comments`, {
      method: 'POST',
      body: JSON.stringify({
        body: `Actualización de auditoría programada (${timestamp})\n\n${summaryBody}${fingerprintsLine}`,
      }),
    });
    return { action: 'commented', issueNumber: targetIssue.number, severeFindingsCount: severeFindings.length };
  }

  const created = await client.request(`/repos/${client.owner}/${client.repo}/issues`, {
    method: 'POST',
    body: JSON.stringify({
      title: `[Scheduled Audit][${branch}] ${report.conclusion} - ${timestamp}`,
      body: `${summaryBody}${fingerprintsLine}`,
      labels,
    }),
  });
  return { action: 'created', issueNumber: created.number, severeFindingsCount: severeFindings.length };
}
