"use client";

import { useState } from "react";
import { doc, updateDoc, serverTimestamp } from "firebase/firestore";
import { db } from "../../../lib/firebase";

interface Props {
  storeId: string;
  currentStatus: string;
}

export default function StoreStatusActions({ storeId, currentStatus }: Props) {
  const [loading, setLoading] = useState(false);

  const updateStatus = async (status: string) => {
    setLoading(true);
    try {
      await updateDoc(doc(db, "stores", storeId), {
        visibilityStatus: status,
        updatedAt: serverTimestamp(),
      });
    } catch (e) {
      alert("Error al actualizar el estado");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex items-center gap-1">
      {currentStatus !== "active" && (
        <button
          onClick={() => updateStatus("active")}
          disabled={loading}
          className="rounded-lg bg-green-50 px-2.5 py-1 text-xs font-medium text-green-700 hover:bg-green-100 disabled:opacity-50 transition-colors"
        >
          Activar
        </button>
      )}
      {currentStatus !== "suspended" && (
        <button
          onClick={() => updateStatus("suspended")}
          disabled={loading}
          className="rounded-lg bg-red-50 px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-100 disabled:opacity-50 transition-colors"
        >
          Suspender
        </button>
      )}
    </div>
  );
}
