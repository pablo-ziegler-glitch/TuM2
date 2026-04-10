const PROD_PROJECT_ID = "tum2-prod-bc9b4";

function readBoolEnv(name: string): boolean | null {
  const raw = process.env[name];
  if (typeof raw !== "string") return null;
  const normalized = raw.trim().toLowerCase();
  if (normalized === "true") return true;
  if (normalized === "false") return false;
  return null;
}

function currentProjectId(): string {
  const raw = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "";
  return raw.trim();
}

/**
 * Cost guard for automatic jobs/triggers that may generate high Firestore volume.
 *
 * Default behavior:
 * - enabled only in prod project (tum2-prod-bc9b4)
 * - disabled in staging/dev
 *
 * Overrides:
 * - AUTOMATIC_FIRESTORE_JOBS_ENABLED=true  -> force enable
 * - AUTOMATIC_FIRESTORE_JOBS_ENABLED=false -> force disable
 */
export function shouldRunAutomaticFirestoreJob(jobName: string): boolean {
  const forced = readBoolEnv("AUTOMATIC_FIRESTORE_JOBS_ENABLED");
  if (forced != null) {
    if (!forced) {
      console.log(
        `[${jobName}] Skipped (AUTOMATIC_FIRESTORE_JOBS_ENABLED=false).`
      );
    }
    return forced;
  }

  const projectId = currentProjectId();
  const enabled = projectId === PROD_PROJECT_ID;
  if (!enabled) {
    console.log(
      `[${jobName}] Skipped on project=${projectId || "unknown"} (non-prod default).`
    );
  }
  return enabled;
}
