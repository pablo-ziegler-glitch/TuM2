import type { Metadata } from "next";
import { adminDb } from "../../lib/firebaseAdmin";
import { DutyScheduleDoc, StoreDoc } from "../../lib/types";
import Link from "next/link";

// No cache: always fetch fresh pharmacy duty data
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Farmacias de turno — TuM2",
  description: "Farmacias de guardia disponibles hoy en tu zona.",
};

function getTodayDate(): string {
  return new Date().toLocaleDateString("en-CA"); // "YYYY-MM-DD"
}

async function getTodayDutySchedules(): Promise<
  (DutyScheduleDoc & { store?: StoreDoc })[]
> {
  const today = getTodayDate();

  try {
    const dutySnap = await adminDb
      .collection("dutySchedules")
      .where("date", "==", today)
      .get();

    const duties = dutySnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })) as DutyScheduleDoc[];

    // Enrich with store data
    const enriched = await Promise.all(
      duties.map(async (duty) => {
        const storeSnap = await adminDb
          .collection("stores")
          .doc(duty.storeId)
          .get();

        return {
          ...duty,
          store: storeSnap.exists
            ? ({ id: storeSnap.id, ...storeSnap.data() } as StoreDoc)
            : undefined,
        };
      })
    );

    return enriched;
  } catch {
    return [];
  }
}

export default async function FarmaciasPage() {
  const duties = await getTodayDutySchedules();

  const today = new Date().toLocaleDateString("es-AR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  return (
    <div>
      <h1 className="mb-1 text-3xl font-bold text-gray-900">
        Farmacias de turno
      </h1>
      <p className="mb-8 capitalize text-tum2-on-surface-variant">{today}</p>

      {duties.length === 0 ? (
        <div className="rounded-2xl border border-tum2-outline bg-tum2-surface py-16 text-center">
          <svg
            className="mx-auto mb-4 h-12 w-12 text-tum2-on-surface-variant"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={1.5}
              d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <p className="text-tum2-on-surface-variant">
            No hay farmacias de turno registradas para hoy.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {duties.map((duty) => (
            <div
              key={duty.id}
              className="flex items-start gap-4 rounded-2xl border border-blue-100 bg-blue-50 p-5"
            >
              <div className="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl bg-blue-100">
                <svg
                  className="h-6 w-6 text-blue-700"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"
                  />
                </svg>
              </div>
              <div className="flex-1">
                {duty.store ? (
                  <Link
                    href={`/${duty.store.slug}`}
                    className="font-semibold text-gray-900 hover:text-tum2-primary"
                  >
                    {duty.store.name}
                  </Link>
                ) : (
                  <p className="font-semibold text-gray-900">{duty.storeId}</p>
                )}
                {duty.store?.address && (
                  <p className="text-sm text-tum2-on-surface-variant">
                    {duty.store.address}
                  </p>
                )}
                <p className="mt-1 text-sm font-medium text-blue-700">
                  {duty.startTime} – {duty.endTime}
                </p>
                {duty.notes && (
                  <p className="mt-1 text-sm text-tum2-on-surface-variant">
                    {duty.notes}
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
