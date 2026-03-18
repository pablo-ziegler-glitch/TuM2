import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { RankType, VoteDoc } from "../types";

// XP awarded per vote received on a proposal
const XP_PER_VOTE = 10;

// Rank thresholds (minimum XP required)
const RANK_THRESHOLDS: { rank: RankType; minXp: number }[] = [
  { rank: "Radar", minXp: 5000 },
  { rank: "Conector", minXp: 1500 },
  { rank: "Referente", minXp: 500 },
  { rank: "Explorador", minXp: 100 },
  { rank: "Vecino", minXp: 0 },
];

/**
 * Calculates the rank based on total XP points.
 */
function calculateRank(xpPoints: number): RankType {
  for (const { rank, minXp } of RANK_THRESHOLDS) {
    if (xpPoints >= minXp) return rank;
  }
  return "Vecino";
}

/**
 * Triggered when a vote is created/deleted on a proposal.
 * Awards XP to the proposal creator and recalculates their rank.
 */
export const onVoteWrite = functions.firestore
  .document("proposals/{proposalId}/votes/{userId}")
  .onWrite(async (change, context) => {
    const proposalId = context.params.proposalId;
    const db = admin.firestore();

    try {
      // Load the proposal to find the creator
      const proposalSnap = await db.collection("proposals").doc(proposalId).get();

      if (!proposalSnap.exists) {
        functions.logger.warn(`Proposal ${proposalId} not found.`);
        return;
      }

      const proposal = proposalSnap.data()!;
      const createdBy: string = proposal.createdBy;

      // Count the total votes for this proposal
      const votesSnap = await db
        .collection("proposals")
        .doc(proposalId)
        .collection("votes")
        .count()
        .get();

      const totalVotes = votesSnap.data().count;

      // Update vote count on the proposal
      await proposalSnap.ref.update({ voteCount: totalVotes });

      // Calculate XP for the proposal creator
      const totalXpFromThisProposal = totalVotes * XP_PER_VOTE;

      // Load the user to get their current XP from other proposals
      const userRef = db.collection("users").doc(createdBy);
      const userSnap = await userRef.get();

      if (!userSnap.exists) {
        functions.logger.warn(`User ${createdBy} not found for XP update.`);
        return;
      }

      const userData = userSnap.data()!;
      const currentXp: number = userData.xpPoints ?? 0;

      // Recalculate total XP: base XP + XP from this proposal's votes
      // We track xpFromOtherSources separately to avoid double-counting
      const previousProposalXp: number = userData[`xpFromProposal_${proposalId}`] ?? 0;
      const xpDelta = totalXpFromThisProposal - previousProposalXp;
      const newTotalXp = Math.max(0, currentXp + xpDelta);
      const newRank = calculateRank(newTotalXp);

      await userRef.update({
        xpPoints: newTotalXp,
        currentRank: newRank,
        [`xpFromProposal_${proposalId}`]: totalXpFromThisProposal,
      });

      functions.logger.info(
        `XP updated for user ${createdBy}: ${currentXp} → ${newTotalXp}, rank: ${newRank}`
      );
    } catch (error) {
      functions.logger.error(
        `Error updating XP for proposal ${proposalId}:`,
        error
      );
      throw error;
    }
  });
