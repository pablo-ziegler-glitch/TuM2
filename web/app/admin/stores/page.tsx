import { adminDb } from "../../../lib/firebaseAdmin";
import { StoreDoc } from "../../../lib/types";
import StoreStatusActions from "./StoreStatusActions";

export const dynamic = "force-dynamic";

async function getAllStores(): Promise<StoreDoc[]> {
  const snap = await adminDb
    .collection("stores")
    .orderBy("createdAt", "desc")
    .limit(100)
    .get();

  return snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as StoreDoc[];
}

const STATUS_LABELS: Record<string, { label: string; className: string }> = {
  active: { label: "Activo", className: "bg-green-50 text-green-700" },
  draft: { label: "Borrador", className: "bg-amber-50 text-amber-700" },
  suspended: { label: "Suspendido", className: "bg-red-50 text-red-700" },
};

export default async function AdminStoresPage() {
  const stores = await getAllStores();

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Comercios</h1>
        <span className="text-sm text-tum2-on-surface-variant">
          {stores.length} total
        </span>
      </div>

      <div className="overflow-hidden rounded-2xl border border-tum2-outline bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-tum2-outline bg-tum2-surface">
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Nombre
              </th>
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Categoría
              </th>
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Localidad
              </th>
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Estado
              </th>
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Señales
              </th>
              <th className="px-4 py-3 text-left font-medium text-gray-600">
                Acciones
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-tum2-outline">
            {stores.map((store) => {
              const status = STATUS_LABELS[store.visibilityStatus] ?? {
                label: store.visibilityStatus,
                className: "bg-gray-100 text-gray-700",
              };

              return (
                <tr key={store.id} className="hover:bg-tum2-surface">
                  <td className="px-4 py-3">
                    <div>
                      <p className="font-medium text-gray-900">{store.name}</p>
                      <p className="text-xs text-tum2-on-surface-variant">
                        /{store.slug}
                      </p>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{store.category}</td>
                  <td className="px-4 py-3 text-gray-600">{store.locality}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium ${status.className}`}
                    >
                      {status.label}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1">
                      {store.isOpenNow && (
                        <span className="h-2 w-2 rounded-full bg-green-500" title="Abierto ahora" />
                      )}
                      {store.isOnDutyToday && (
                        <span className="h-2 w-2 rounded-full bg-blue-500" title="De turno hoy" />
                      )}
                      {store.hasActiveSpecialSignal && (
                        <span className="h-2 w-2 rounded-full bg-amber-500" title="Señal especial activa" />
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <StoreStatusActions
                      storeId={store.id}
                      currentStatus={store.visibilityStatus}
                    />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
