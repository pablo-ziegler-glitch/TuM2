"use client";

import { useState } from "react";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "../../../lib/firebase";

interface Props {
  proposalId: string;
  currentStatus: string;
  currentModeration: string;
}

const STATUS_OPTIONS = [
  { value: "open", label: "Abierta" },
  { value: "in_review", label: "En revisión" },
  { value: "planned", label: "Planificada" },
  { value: "done", label: "Implementada" },
  { value: "rejected", label: "Rechazada" },
];

export default function ProposalModerationActions({
  proposalId,
  currentStatus,
  currentModeration,
}: Props) {
  const [loading, setLoading] = useState(false);

  const updateModeration = async (moderationStatus: string) => {
    setLoading(true);
    try {
      await updateDoc(doc(db, "proposals", proposalId), {
        moderationStatus,
      });
    } finally {
      setLoading(false);
    }
  };

  const updateStatus = async (status: string) => {
    setLoading(true);
    try {
      await updateDoc(doc(db, "proposals", proposalId), { status });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-2">
      {/* Moderation */}
      {currentModeration === "pending" && (
        <div className="flex gap-1">
          <button
            onClick={() => updateModeration("approved")}
            disabled={loading}
            className="rounded-lg bg-green-50 px-2.5 py-1 text-xs font-medium text-green-700 hover:bg-green-100 disabled:opacity-50"
          >
            Aprobar
          </button>
          <button
            onClick={() => updateModeration("rejected")}
            disabled={loading}
            className="rounded-lg bg-red-50 px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-100 disabled:opacity-50"
          >
            Rechazar
          </button>
        </div>
      )}

      {/* Status change */}
      <select
        value={currentStatus}
        onChange={(e) => updateStatus(e.target.value)}
        disabled={loading}
        className="rounded-lg border border-tum2-outline px-2 py-1 text-xs text-gray-700 outline-none focus:border-tum2-primary"
      >
        {STATUS_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}
