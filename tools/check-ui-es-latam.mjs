import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const includeRoots = ['web/lib', 'web/web', 'mobile/lib'];
const uiDirHints = [
  '/screens/',
  '/presentation/',
  '/shell/',
  '/shared/widgets/',
  '/widgets/',
];
const allowedFiles = new Set(['web/web/index.html']);
const lineMatchers = [
  'Text(',
  'labelText:',
  'hintText:',
  'tooltip:',
  'Tab(text:',
  '_headerCell(',
  'title:',
  'label:',
  'description:',
  'message:',
  'emptyLabel:',
];
const bannedPatterns = [
  /\bDashboard\b/i,
  /\bImport Management\b/i,
  /\bCatalog Limits\b/i,
  /\bClaims Review\b/i,
  /\bTemplates\b/i,
  /\bAnalytics\b/i,
  /\bSettings\b/i,
  /\bPassword\b/i,
  /\bSelect Import Type\b/i,
  /\bSelect Template\b/i,
  /\bField Mapping\b/i,
  /\bConfirm Import\b/i,
  /\bValidation & Preview\b/i,
  /\bImport not found\b/i,
  /\bProcessing Timeline\b/i,
  /\bValidation Issues\b/i,
  /\bFile Intelligence\b/i,
  /\bActor Context\b/i,
  /\bConflict Logic\b/i,
  /\bReady to Import\b/i,
  /\bReady with warnings\b/i,
  /\bClear filters\b/i,
  /\bGet Directions\b/i,
  /\bExpand Map\b/i,
  /\bDuty Reassignment\b/i,
  /\bSearch by name or neighborhood\b/i,
  /\bClose to me\b/i,
  /\bOpen Now\b/i,
  /\bActive Pharmacies\b/i,
  /\bMap Overview\b/i,
  /\bINTERACTIVE VIEW\b/i,
  /\bCustom Schema\b/i,
  /\bOfficial Dataset\b/i,
  /\bMaster Catalog\b/i,
  /\bGeneric \/ Internal\b/i,
];

function walk(dir) {
  const entries = readdirSync(dir);
  const files = [];
  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stats = statSync(fullPath);
    if (stats.isDirectory()) {
      files.push(...walk(fullPath));
    } else {
      files.push(fullPath);
    }
  }
  return files;
}

function isUiFile(path) {
  const normalized = path.replaceAll('\\', '/');
  if (allowedFiles.has(normalized)) return true;
  return uiDirHints.some((hint) => normalized.includes(hint));
}

const files = includeRoots
  .flatMap((dir) => walk(join(root, dir)))
  .map((file) => relative(root, file).replaceAll('\\', '/'))
  .filter((file) => file.endsWith('.dart') || file.endsWith('.html'))
  .filter(isUiFile);

const findings = [];

for (const file of files) {
  const content = readFileSync(join(root, file), 'utf8');
  const lines = content.split('\n');
  lines.forEach((line, index) => {
    if (!lineMatchers.some((matcher) => line.includes(matcher))) return;
    for (const pattern of bannedPatterns) {
      if (!pattern.test(line)) continue;
      findings.push({
        file,
        line: index + 1,
        text: line.trim(),
      });
      break;
    }
  });
}

if (findings.length > 0) {
  console.error('Se detecto microcopy potencialmente no ES-LATAM en UI:');
  for (const finding of findings) {
    console.error(`- ${finding.file}:${finding.line} ${finding.text}`);
  }
  process.exit(1);
}

console.log('Verificacion ES-LATAM de UI OK.');
