import { adminDb } from "../../../lib/firebaseAdmin";
import { ProposalDoc } from "../../../lib/types";
import ProposalModerationActions from "./ProposalModerationActions";

export const dynamic = "force-dynamic";

async function getAllProposals(): Promise<ProposalDoc[]> {
  const snap = await adminDb
    .collection("proposals")
    .orderBy("createdAt", "desc")
    .limit(100)
    .get();

  return snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as ProposalDoc[];
}

const MODERATION_STYLES: Record<string, string> = {
  pending: "bg-amber-50 text-amber-700",
  approved: "bg-green-50 text-green-700",
  rejected: "bg-red-50 text-red-700",
};

const STATUS_STYLES: Record<string, string> = {
  open: "bg-blue-50 text-blue-700",
  in_review: "bg-purple-50 text-purple-700",
  planned: "bg-teal-50 text-teal-700",
  done: "bg-green-50 text-green-700",
  rejected: "bg-red-50 text-red-700",
};

export default async function AdminProposalsPage() {
  const proposals = await getAllProposals();

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Propuestas</h1>
        <span className="text-sm text-tum2-on-surface-variant">
          {proposals.length} total
        </span>
      </div>

      <div className="flex flex-col gap-4">
        {proposals.map((proposal) => (
          <div
            key={proposal.id}
            className="rounded-2xl border border-tum2-outline bg-white p-5"
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                <div className="mb-1 flex flex-wrap items-center gap-2">
                  <span className="text-xs font-medium text-tum2-on-surface-variant">
                    {proposal.segment}
                  </span>
                  <span
                    className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      MODERATION_STYLES[proposal.moderationStatus]
                    }`}
                  >
                    {proposal.moderationStatus}
                  </span>
                  <span
                    className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      STATUS_STYLES[proposal.status] ?? "bg-gray-50 text-gray-600"
                    }`}
                  >
                    {proposal.status}
                  </span>
                  <span className="text-xs text-tum2-on-surface-variant">
                    {proposal.voteCount} votos
                  </span>
                </div>
                <h3 className="font-semibold text-gray-900">{proposal.title}</h3>
                {proposal.description && (
                  <p className="mt-1 text-sm text-tum2-on-surface-variant">
                    {proposal.description}
                  </p>
                )}
              </div>
              <ProposalModerationActions
                proposalId={proposal.id}
                currentStatus={proposal.status}
                currentModeration={proposal.moderationStatus}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
