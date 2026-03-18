import { adminDb } from "../lib/firebaseAdmin";
import { StoreDoc } from "../lib/types";
import StoreCard from "../components/StoreCard";

// Revalidate every 60 seconds (ISR)
export const revalidate = 60;

async function getActiveStores(): Promise<StoreDoc[]> {
  try {
    const snap = await adminDb
      .collection("stores")
      .where("visibilityStatus", "==", "active")
      .orderBy("updatedAt", "desc")
      .limit(50)
      .get();

    return snap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })) as StoreDoc[];
  } catch {
    return [];
  }
}

export default async function HomePage() {
  const stores = await getActiveStores();

  return (
    <div>
      {/* Hero */}
      <section className="mb-10 text-center">
        <h1 className="mb-3 text-4xl font-bold text-tum2-primary">
          TuM2
        </h1>
        <p className="text-lg text-tum2-on-surface-variant">
          Los comercios de tu zona, siempre actualizados.
        </p>
      </section>

      {/* Stores list */}
      <section>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">
            Comercios activos
          </h2>
          <span className="text-sm text-tum2-on-surface-variant">
            {stores.length} encontrados
          </span>
        </div>

        {stores.length === 0 ? (
          <div className="rounded-2xl border border-tum2-outline bg-tum2-surface py-16 text-center">
            <p className="text-tum2-on-surface-variant">
              El barrio está esperando sus primeros comercios.
            </p>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            {stores.map((store) => (
              <StoreCard key={store.id} store={store} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
