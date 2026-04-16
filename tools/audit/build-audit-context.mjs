import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';

const execFileAsync = promisify(execFile);

const EXCLUDED_PATTERNS = [
  /^\.env/i,
  /^node_modules\//,
  /^build\//,
  /^dist\//,
  /^mobile\/build\//,
  /^mobile\/\.dart_tool\//,
  /^artifacts\//,
  /\.zip$/i,
  /\.tar$/i,
  /\.gz$/i,
  /^google-services\.json$/,
  /^GoogleService-Info\.plist$/,
];

const KNOWN_COLLECTION_HINTS = [
  'merchant_public',
  'merchants',
  'operational_signals',
  'pharmacy_duties',
  'owner_pending',
  'claims',
  'zoneId',
  'categoryId',
];

export function classifyDomain(filePath) {
  if (filePath.startsWith('functions/')) return 'functions';
  if (filePath.startsWith('mobile/')) return 'mobile';
  if (filePath.startsWith('web/')) return 'web';
  if (
    filePath === 'firestore.rules' ||
    filePath === 'storage.rules' ||
    filePath === 'firebase.json' ||
    filePath === 'firestore.indexes.json' ||
    filePath.startsWith('.github/workflows/')
  ) {
    return 'infra';
  }
  if (filePath.startsWith('schema/')) return 'schema';
  return 'other';
}

export function shouldExcludePath(filePath) {
  return EXCLUDED_PATTERNS.some((pattern) => pattern.test(filePath));
}

export function extractCollectionKeywords(text) {
  const matches = new Set(KNOWN_COLLECTION_HINTS.filter((hint) => text.includes(hint)));
  const generic = text.match(/\b[a-z]+_[a-z0-9_]+\b/g) ?? [];
  for (const token of generic) {
    if (token.length > 4 && token.length < 40) matches.add(token);
  }
  return [...matches].slice(0, 20);
}

async function runGit(args, { allowFailure = false } = {}) {
  try {
    const { stdout } = await execFileAsync('git', args, { maxBuffer: 16 * 1024 * 1024 });
    return stdout.trimEnd();
  } catch (error) {
    if (allowFailure) return '';
    throw error;
  }
}

async function getChangedFiles(baseSha, targetSha) {
  const output = await runGit(['diff', '--name-only', '--diff-filter=ACMRT', `${baseSha}..${targetSha}`]);
  return output
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((filePath) => !shouldExcludePath(filePath));
}

async function readFileAtCommit(sha, filePath, maxCharsPerFile) {
  const text = await runGit(['show', `${sha}:${filePath}`], { allowFailure: true });
  if (!text) return '';
  return text.length > maxCharsPerFile ? `${text.slice(0, maxCharsPerFile)}\n\n[TRUNCADO ${text.length - maxCharsPerFile} chars]` : text;
}

async function collectReferenceMatches(keywords, maxRefsPerKeyword = 20) {
  if (keywords.length === 0) return [];
  const roots = ['functions/src', 'mobile/lib', 'web/lib', 'schema/types'];
  const found = new Set();
  for (const keyword of keywords) {
    const rgArgs = ['-l', '--glob', '!.dart_tool/**', '--glob', '!node_modules/**', '--max-count', '1', '--fixed-strings', keyword, ...roots];
    const output = await execFileAsync('rg', rgArgs, { maxBuffer: 6 * 1024 * 1024 }).then((r) => r.stdout, () => '');
    const refs = output
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .slice(0, maxRefsPerKeyword);
    for (const ref of refs) found.add(ref);
    if (found.size >= 80) break;
  }
  return [...found];
}

function inferStaticRelatedFiles(changedFiles, keywords) {
  const related = new Set();
  const touchedFunctions = changedFiles.some((f) => f.startsWith('functions/src/'));
  const touchedMobile = changedFiles.some((f) => f.startsWith('mobile/'));
  const touchedSchema = changedFiles.some((f) => f.startsWith('schema/types/'));
  const touchedInfra = changedFiles.some(
    (f) => f === 'firestore.rules' || f === 'storage.rules' || f === 'firebase.json' || f === 'firestore.indexes.json' || f.startsWith('.github/workflows/'),
  );

  if (touchedFunctions) {
    related.add('schema/types');
    related.add('firestore.rules');
    related.add('firestore.indexes.json');
    related.add('firebase.json');
  }
  if (touchedMobile) {
    related.add('functions/src');
    related.add('firestore.rules');
  }
  if (touchedSchema) {
    related.add('functions/src');
    related.add('mobile/lib');
    related.add('web/lib');
  }
  if (touchedInfra) {
    related.add('functions/src');
    related.add('mobile/lib');
    related.add('web/lib');
    related.add('docs/ops');
  }

  if (keywords.some((k) => ['merchant_public', 'claims', 'owner_pending', 'pharmacy_duties', 'operational_signals'].includes(k))) {
    related.add('functions/src');
    related.add('mobile/lib');
    related.add('web/lib');
    related.add('firestore.rules');
  }
  return [...related];
}

async function expandDirectories(pathsOrFiles) {
  const files = new Set();
  for (const candidate of pathsOrFiles) {
    try {
      const stats = await fs.stat(candidate);
      if (stats.isDirectory()) {
        const listed = await execFileAsync('rg', ['--files', candidate], { maxBuffer: 8 * 1024 * 1024 }).then((r) => r.stdout, () => '');
        listed
          .split('\n')
          .map((line) => line.trim())
          .filter(Boolean)
          .forEach((item) => files.add(item));
      } else {
        files.add(candidate);
      }
    } catch {
      // Ignorar paths no existentes.
    }
  }
  return [...files].filter((filePath) => !shouldExcludePath(filePath));
}

async function buildBatch({ files, baseSha, targetSha, maxInputChars, maxCharsPerFile }) {
  const selected = [];
  let chars = 0;
  const diffByBatch = await runGit(['diff', '--unified=3', '--no-color', `${baseSha}..${targetSha}`, '--', ...files], { allowFailure: true });
  const cappedDiff =
    diffByBatch.length > Math.floor(maxInputChars * 0.55)
      ? `${diffByBatch.slice(0, Math.floor(maxInputChars * 0.55))}\n\n[DIFF TRUNCADO ${diffByBatch.length} chars]`
      : diffByBatch;
  chars += cappedDiff.length;

  for (const filePath of files) {
    if (selected.length >= 25) break;
    if (chars >= maxInputChars) break;
    const content = await readFileAtCommit(targetSha, filePath, maxCharsPerFile);
    if (!content) continue;
    if (chars + content.length > maxInputChars) break;
    selected.push({ path: filePath, domain: classifyDomain(filePath), content });
    chars += content.length;
  }

  return {
    files: selected,
    diff: cappedDiff,
    totalInputChars: chars,
    filesOmitted: files.length - selected.length,
  };
}

export async function buildAuditContext({
  baseSha,
  targetSha,
  maxFiles = 25,
  maxInputChars = 220000,
  forceFullAudit = false,
}) {
  const maxCharsPerFile = 12000;
  const changedFiles = forceFullAudit
    ? (
        await runGit(['ls-tree', '-r', '--name-only', targetSha], { allowFailure: false })
      )
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .filter((filePath) => !shouldExcludePath(filePath))
        .slice(0, 180)
    : await getChangedFiles(baseSha, targetSha);

  if (changedFiles.length === 0) {
    return {
      hasChanges: false,
      changedFiles: [],
      relatedFiles: [],
      batches: [],
      changedAreas: [],
    };
  }

  const globalDiff = await runGit(['diff', '--unified=3', '--no-color', `${baseSha}..${targetSha}`, '--', ...changedFiles], { allowFailure: true });
  const keywords = extractCollectionKeywords(globalDiff);
  const staticRelated = inferStaticRelatedFiles(changedFiles, keywords);
  const referencedFiles = await collectReferenceMatches(keywords);
  const expandedStatic = await expandDirectories(staticRelated);
  const mergedRelated = [...new Set([...expandedStatic, ...referencedFiles])]
    .filter((filePath) => !changedFiles.includes(filePath))
    .filter((filePath) => !shouldExcludePath(filePath))
    .slice(0, 80);

  const allCandidateFiles = [...new Set([...changedFiles, ...mergedRelated])];
  const grouped = new Map();
  for (const filePath of allCandidateFiles) {
    const domain = classifyDomain(filePath);
    if (!grouped.has(domain)) grouped.set(domain, []);
    grouped.get(domain).push(filePath);
  }

  const changedAreas = [...new Set(changedFiles.map(classifyDomain))];
  const batches = [];
  for (const [domain, files] of grouped.entries()) {
    const cappedFiles = files.slice(0, maxFiles);
    const batch = await buildBatch({
      files: cappedFiles,
      baseSha,
      targetSha,
      maxInputChars,
      maxCharsPerFile,
    });
    batches.push({
      domain,
      ...batch,
      sourceFiles: cappedFiles,
    });
  }

  return {
    hasChanges: true,
    changedFiles,
    relatedFiles: mergedRelated,
    changedAreas,
    keywords,
    batches,
  };
}
