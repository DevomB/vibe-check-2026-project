export interface Pot {
  amount: number;
  /** Seat indexes that can win this pot (they put in enough chips and did not fold). */
  eligible: number[];
}

/**
 * Splits the chips put in during a hand into the main pot and side pots.
 * `contributed[i]` is what seat i put in this hand; folded seats' chips count
 * toward the pots but those seats cannot win them.
 */
export function buildPots(contributed: readonly number[], folded: readonly boolean[]): Pot[] {
  const live = contributed.map((_, i) => i).filter((i) => !folded[i] && contributed[i]! > 0);
  const levels = [...new Set(live.map((i) => contributed[i]!))].sort((a, b) => a - b);

  const pots: Pot[] = [];
  let previous = 0;
  for (const level of levels) {
    let amount = 0;
    for (const c of contributed) amount += Math.max(0, Math.min(c, level) - previous);
    const eligible = live.filter((i) => contributed[i]! >= level);
    const last = pots[pots.length - 1];
    if (last && last.eligible.length === eligible.length) last.amount += amount;
    else pots.push({ amount, eligible });
    previous = level;
  }

  // Chips folded above every live player's total (not normally possible once
  // uncalled bets are returned) go to the last pot rather than vanishing.
  const leftover = contributed.reduce((sum, c) => sum + Math.max(0, c - previous), 0);
  if (leftover > 0 && pots.length > 0) pots[pots.length - 1]!.amount += leftover;
  return pots;
}

/**
 * Splits `amount` evenly between `winners`. Odd chips go one at a time to the
 * winners closest to the left of the button, as in casino rules.
 */
export function splitPot(amount: number, winners: readonly number[], button: number, seatCount: number): Map<number, number> {
  const share = Math.floor(amount / winners.length);
  let remainder = amount - share * winners.length;
  const order = winners.slice().sort((a, b) => ((a - button - 1 + seatCount) % seatCount) - ((b - button - 1 + seatCount) % seatCount));
  const result = new Map<number, number>();
  for (const w of order) {
    result.set(w, share + (remainder > 0 ? 1 : 0));
    if (remainder > 0) remainder--;
  }
  return result;
}
