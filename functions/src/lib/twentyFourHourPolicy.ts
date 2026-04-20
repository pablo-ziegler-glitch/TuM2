export interface TwentyFourHourPolicyState {
  is24hEnabled: boolean;
  strikeCount: number;
  cooldownUntilMs: number | null;
}

export interface TwentyFourHourPolicyInput {
  previousIsOpenNow: boolean;
  nextIsOpenNow: boolean;
  nowMs: number;
  state: TwentyFourHourPolicyState;
}

export interface TwentyFourHourPolicyResult {
  next: TwentyFourHourPolicyState;
  removedBecauseClosed: boolean;
}

const FIRST_PENALTY_HOURS = 24;
const REPEATED_PENALTY_HOURS = 24 * 7;

export function canUse24hBadge(state: TwentyFourHourPolicyState, nowMs: number): boolean {
  if (!state.is24hEnabled) return false;
  if (state.cooldownUntilMs == null) return true;
  return nowMs >= state.cooldownUntilMs;
}

export function apply24hClosePolicy(input: TwentyFourHourPolicyInput): TwentyFourHourPolicyResult {
  const { previousIsOpenNow, nextIsOpenNow, nowMs, state } = input;

  const closedTransition = previousIsOpenNow && !nextIsOpenNow;
  if (!closedTransition || !state.is24hEnabled) {
    return {
      next: state,
      removedBecauseClosed: false,
    };
  }

  const nextStrikeCount = Math.max(0, state.strikeCount) + 1;
  const penaltyHours = nextStrikeCount == 1 ? FIRST_PENALTY_HOURS : REPEATED_PENALTY_HOURS;

  return {
    next: {
      is24hEnabled: false,
      strikeCount: nextStrikeCount,
      cooldownUntilMs: nowMs + penaltyHours * 60 * 60 * 1000,
    },
    removedBecauseClosed: true,
  };
}

