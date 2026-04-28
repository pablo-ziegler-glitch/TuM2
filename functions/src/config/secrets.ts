import { defineSecret } from "firebase-functions/params";

export const SLACK_WEBHOOK_URL_SECRET = defineSecret("SLACK_WEBHOOK_URL");
export const IP_HASH_SALT_SECRET = defineSecret("IP_HASH_SALT");
export const CLAIM_SENSITIVE_KEY_B64_SECRET = defineSecret("CLAIM_SENSITIVE_KEY_B64");
