import type { Metadata } from "next";
import { adminDb } from "../../../lib/firebaseAdmin";
import { StoreDoc } from "../../../lib/types";
import StoreCard from "../../../components/StoreCard";

export const revalidate = 60;

interface PageProps {
  params: { id: string };
}

const CATEGORY_LABELS: Record<string, string> = {
  farmacia: "Farmacia",
  almacen: "Almacén",
  panaderia: "Panadería",
  kiosco: "Kiosco",
  verduleria: "Verdulería",
  carniceria: "Carnicería",
};

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const label = CATEGORY_LABELS[params.id] ?? params.id;
  return {
    title: `${label} — TuM2`,
    description: `Comercios de la categoría ${label} en tu zona.`,
  };
}

async function getStoresByCategory(category: string): Promise<StoreDoc[]> {
  try {
    const snap = await adminDb
      .collection("stores")
      .where("visibilityStatus", "==", "active")
      .where("category", "==", category)
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

export default async function CategoryPage({ params }: PageProps) {
  const categoryLabel = CATEGORY_LABELS[params.id] ?? params.id;
  const stores = await getStoresByCategory(categoryLabel);

  return (
    <div>
      <h1 className="mb-6 text-3xl font-bold text-gray-900">
        {categoryLabel}
      </h1>

      {stores.length === 0 ? (
        <div className="rounded-2xl border border-tum2-outline bg-tum2-surface py-16 text-center">
          <p className="text-tum2-on-surface-variant">
            No hay comercios en esta categoría aún.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {stores.map((store) => (
            <StoreCard key={store.id} store={store} />
          ))}
        </div>
      )}
    </div>
  );
}
