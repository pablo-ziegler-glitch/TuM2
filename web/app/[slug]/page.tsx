import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { adminDb } from "../../lib/firebaseAdmin";
import { StoreDoc, ProductDoc, OperationalSignalDoc, ScheduleDoc } from "../../lib/types";
import OpenStatusBadge from "../../components/OpenStatusBadge";
import SignalBadges from "../../components/SignalBadges";

// ISR: revalidate every 60 seconds
export const revalidate = 60;

interface PageProps {
  params: { slug: string };
}

export async function generateStaticParams() {
  try {
    const snap = await adminDb
      .collection("stores")
      .where("visibilityStatus", "==", "active")
      .select("slug")
      .limit(200)
      .get();

    return snap.docs
      .map((doc) => ({ slug: doc.data().slug as string }))
      .filter((p) => p.slug);
  } catch {
    return [];
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const store = await getStoreBySlug(params.slug);
  if (!store) return { title: "Comercio no encontrado — TuM2" };

  return {
    title: `${store.name} — TuM2`,
    description: store.description || `${store.name} en ${store.address}`,
    openGraph: {
      title: store.name,
      description: store.description,
      images: store.imageUrl ? [store.imageUrl] : [],
    },
  };
}

async function getStoreBySlug(slug: string): Promise<StoreDoc | null> {
  const snap = await adminDb
    .collection("stores")
    .where("slug", "==", slug)
    .where("visibilityStatus", "==", "active")
    .limit(1)
    .get();

  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() } as StoreDoc;
}

async function getStoreProducts(storeId: string): Promise<ProductDoc[]> {
  const snap = await adminDb
    .collection("stores")
    .doc(storeId)
    .collection("products")
    .where("isVisible", "==", true)
    .limit(30)
    .get();

  return snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as ProductDoc[];
}

async function getActiveSignals(storeId: string): Promise<OperationalSignalDoc[]> {
  const snap = await adminDb
    .collection("stores")
    .doc(storeId)
    .collection("operationalSignals")
    .where("status", "==", "active")
    .get();

  return snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as OperationalSignalDoc[];
}

const DAY_NAMES = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
const DAY_KEYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

export default async function StoreDetailPage({ params }: PageProps) {
  const store = await getStoreBySlug(params.slug);

  if (!store) notFound();

  const [products, signals] = await Promise.all([
    getStoreProducts(store.id),
    getActiveSignals(store.id),
  ]);

  const freshnessLabel = store.operationalFreshnessHours >= 9999
    ? "Sin datos operativos"
    : store.operationalFreshnessHours < 24
    ? `Actualizado hace ${store.operationalFreshnessHours}h`
    : `Actualizado hace ${Math.round(store.operationalFreshnessHours / 24)} días`;

  return (
    <div className="max-w-2xl mx-auto">
      {/* Store header */}
      <div className="mb-6">
        {store.imageUrl && (
          <div className="mb-4 overflow-hidden rounded-2xl">
            <img
              src={store.imageUrl}
              alt={store.name}
              className="h-56 w-full object-cover"
            />
          </div>
        )}

        <h1 className="text-3xl font-bold text-gray-900">{store.name}</h1>
        <p className="mt-1 text-tum2-on-surface-variant">{store.category}</p>

        {/* Status */}
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <OpenStatusBadge
            isOpenNow={store.isOpenNow}
            isOnDutyToday={store.isOnDutyToday}
            isLateNight={store.isLateNightNow}
          />
          <span className="text-xs text-tum2-on-surface-variant">
            {freshnessLabel}
          </span>
        </div>

        {/* Active signals */}
        {signals.length > 0 && (
          <div className="mt-3">
            <SignalBadges signals={signals} />
          </div>
        )}

        {/* Address */}
        {store.address && (
          <p className="mt-3 flex items-start gap-1.5 text-sm text-tum2-on-surface-variant">
            <svg className="mt-0.5 h-4 w-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            {store.address}
          </p>
        )}

        {/* Description */}
        {store.description && (
          <p className="mt-4 text-gray-700 leading-relaxed">{store.description}</p>
        )}
      </div>

      {/* Badges */}
      {store.activeBadgeKeys?.length > 0 && (
        <div className="mb-6">
          <div className="flex flex-wrap gap-2">
            {store.activeBadgeKeys.map((key) => (
              <span
                key={key}
                className="inline-flex items-center rounded-full bg-tum2-primary/10 px-3 py-1 text-xs font-medium text-tum2-primary"
              >
                {key.replace(/_/g, " ")}
              </span>
            ))}
          </div>
        </div>
      )}

      <hr className="my-6 border-tum2-outline" />

      {/* Products */}
      <section>
        <h2 className="mb-4 text-xl font-semibold">Productos</h2>
        {products.length === 0 ? (
          <p className="text-tum2-on-surface-variant">
            Este comercio aún no cargó productos.
          </p>
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {products.map((product) => (
              <div
                key={product.id}
                className="overflow-hidden rounded-xl border border-tum2-outline"
              >
                <div className="flex h-32 items-center justify-center bg-tum2-surface-variant">
                  {product.imageUrls?.[0] ? (
                    <img
                      src={product.imageUrls[0]}
                      alt={product.name}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <svg className="h-10 w-10 text-tum2-on-surface-variant" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  )}
                </div>
                <div className="p-3">
                  <p className="truncate text-sm font-medium">{product.name}</p>
                  <p className="text-sm font-semibold text-tum2-primary">
                    ${product.price.toLocaleString("es-AR")}
                  </p>
                  {product.stockStatus === "out" && (
                    <span className="text-xs text-red-600">Sin stock</span>
                  )}
                  {product.stockStatus === "low" && (
                    <span className="text-xs text-amber-600">Poco stock</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
