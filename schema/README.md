# TuM2 — Firestore Schema v1

Schema base for the TuM2 MVP. All TypeScript types live in `schema/types/`.

---

## Collections

| Collection | Document ID | Purpose |
|---|---|---|
| `users` | `{userId}` | Auth users and role management |
| `zones` | `{zoneId}` | Geographic zones (barrios) |
| `merchants` | `{merchantId}` | Canonical commerce entity |
| `merchant_public` | `{merchantId}` | Read-optimized public view (Cloud Functions write only) |
| `merchant_schedules` | `{merchantId}` | Operating hours |
| `merchant_operational_signals` | `{merchantId}` | Real-time operational state |
| `merchant_products` | `{productId}` | Products offered by a merchant |
| `pharmacy_duties` | `{dutyId}` | Pharmacy on-duty (turno de guardia) schedule |
| `external_places` | `{externalPlaceDocId}` | Raw data from Google Places (admin only) |
| `import_batches` | `{batchId}` | External import pipeline audit log |
| `merchant_claims` | `{claimId}` | Ownership claim requests |
| `reports` | `{reportId}` | User-submitted data quality reports |
| `admin_configs` | `global` (singleton) | Feature flags and operational thresholds |

---

## Conventions

- **Timestamps**: `createdAt`, `updatedAt`, `lastReviewedAt`, etc. Use Firestore `Timestamp`.
- **IDs**: human-readable strings where possible — `zone_adrogue_centro`, `mrc_001`.
- **Status axes** (three separate fields on merchants):
  - `status` — lifecycle: `draft | active | inactive | archived`
  - `visibilityStatus` — public exposure: `hidden | review_pending | visible | suppressed`
  - `verificationStatus` — trust level (see below)
- **`sourceType`**: always present on entities that may originate from external or community sources.
- **`normalizedName`**: lowercase, accent-stripped version of `name`, used for dedup and search.

---

## Verification levels (trust order, descending)

| Level | Meaning |
|---|---|
| `verified` | Fully verified, official confirmation |
| `validated` | Admin-reviewed and confirmed |
| `claimed` | Owner has claimed and the claim was approved |
| `referential` | Seeded from a reliable external source (e.g. Google Places) |
| `community_submitted` | Submitted by a user, not yet reviewed |
| `unverified` | No verification at all |

---

## sortBoost reference

| verificationStatus | sortBoost |
|---|---|
| `verified` | 100 |
| `validated` | 90 |
| `claimed` | 80 |
| `referential` | 70 |
| `community_submitted` | 40 |
| `unverified` | 20 |

---

## Merchant publication rules

A merchant can reach `visibilityStatus = visible` when:

1. `name` is present
2. `categoryId` is present
3. `zoneId` is present
4. `primaryLocation.lat` and `primaryLocation.lng` are present
5. `verificationStatus` is at least `referential` or `community_submitted`
6. `status` is neither `inactive` nor `archived`

Community-submitted merchants with partial data go to `review_pending` and may display with `pending_validation` badge if the zone needs density coverage.

---

## Community-submitted flow

```
user submits → community_submitted + review_pending
                  │
          zone needs density?
          ├─ yes → visible + badge: pending_validation
          └─ no  → hidden, queued for review
                         │
                  admin reviews
                  ├─ approved → validated + visible
                  └─ rejected → suppressed
```

---

## Composite indexes

### `merchant_public`
1. `zoneId ASC + visibilityStatus ASC`
2. `zoneId ASC + visibilityStatus ASC + isOpenNow ASC`
3. `zoneId ASC + visibilityStatus ASC + categoryId ASC`
4. `cityId ASC + visibilityStatus ASC + categoryId ASC`
5. `zoneId ASC + hasPharmacyDutyToday ASC + visibilityStatus ASC`
6. `zoneId ASC + visibilityStatus ASC + sortBoost DESC`

### `pharmacy_duties`
1. `zoneId ASC + date ASC + status ASC`
2. `merchantId ASC + date ASC`

### `merchant_products`
1. `merchantId ASC + visibilityStatus ASC`
2. `merchantId ASC + status ASC`

### `external_places`
1. `zoneId ASC + importStatus ASC`
2. `batchId ASC + importStatus ASC`

### `merchants`
1. `zoneId ASC + visibilityStatus ASC + status ASC`
2. `zoneId ASC + categoryId ASC + status ASC`

### `merchant_claims`
1. `merchantId ASC + status ASC`
2. `userId ASC + status ASC`

### `reports`
1. `targetType ASC + status ASC + createdAt DESC`
2. `targetId ASC + status ASC`

---

## MVP-required collections

Build these first:

- `users`
- `zones`
- `merchants`
- `merchant_public`
- `merchant_schedules`
- `merchant_operational_signals`
- `pharmacy_duties`
- `external_places`

Second phase:

- `merchant_products`
- `merchant_claims`
- `reports`
- `import_batches`
- `admin_configs`

---

## Access rules summary

| Collection | Public read | Owner write | Admin write |
|---|---|---|---|
| `users` | own only | own (except role) | ✓ |
| `zones` | ✓ | — | ✓ |
| `merchants` | visible+active only | own merchant | ✓ |
| `merchant_public` | ✓ | — (Cloud Functions) | — (Cloud Functions) |
| `merchant_schedules` | ✓ | own merchant | ✓ |
| `merchant_operational_signals` | ✓ | own merchant | ✓ |
| `merchant_products` | visible only | own merchant | ✓ |
| `pharmacy_duties` | published only | read own + mutate vía callable | ✓ |
| `external_places` | — | — | ✓ |
| `import_batches` | — | — | ✓ |
| `merchant_claims` | own only | create own | ✓ |
| `reports` | — | create own | ✓ |
| `admin_configs` | — | — | read (super: write) |
