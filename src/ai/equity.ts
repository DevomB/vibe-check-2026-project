import { type Card, type Rng, fullDeck, isCard } from "../engine/cards";
import { evaluate } from "../engine/evaluator";

/**
 * Estimates the chance that `hole` wins at showdown against `opponents` random
 * hands, by dealing out random opponent cards and the rest of the board.
 * Ties count as a fractional share. Returns a number from 0 to 1.
 */
export function estimateEquity(hole: Card[], board: Card[], opponents: number, iterations: number, rng: Rng): number {
  if (!Number.isSafeInteger(opponents) || opponents < 0) throw new Error("opponents must be a non-negative safe integer");
  if (!Number.isSafeInteger(iterations) || iterations <= 0) throw new Error("iterations must be a positive safe integer");

  const known = new Set<Card>([...hole, ...board]);
  if (hole.length !== 2 || board.length > 5 || known.size !== hole.length + board.length || ![...known].every(isCard)) {
    throw new Error("Expected two hole cards and up to five board cards, all distinct and valid");
  }
  if (opponents === 0) return 1;
  const pool = fullDeck().filter((c) => !known.has(c));
  const missingBoard = 5 - board.length;
  const needed = opponents * 2 + missingBoard;
  if (needed > pool.length) throw new Error("Not enough cards for that many opponents");

  const mine: Card[] = [...hole, ...board];
  const theirs: Card[] = ["2c", "2c", ...board];
  let won = 0;

  for (let it = 0; it < iterations; it++) {
    // Partial Fisher–Yates: only the first `needed` cards are drawn.
    for (let k = 0; k < needed; k++) {
      const j = k + Math.floor(rng() * (pool.length - k));
      const tmp = pool[k]!;
      pool[k] = pool[j]!;
      pool[j] = tmp;
    }
    // Complete the board in both hand buffers.
    mine.length = 2 + board.length;
    theirs.length = 2 + board.length;
    for (let k = 0; k < missingBoard; k++) {
      const card = pool[opponents * 2 + k]!;
      mine.push(card);
      theirs.push(card);
    }

    const myScore = evaluate(mine).score;
    let tied = 1;
    let lost = false;
    for (let o = 0; o < opponents; o++) {
      theirs[0] = pool[o * 2]!;
      theirs[1] = pool[o * 2 + 1]!;
      const score = evaluate(theirs).score;
      if (score > myScore) {
        lost = true;
        break;
      }
      if (score === myScore) tied++;
    }
    if (!lost) won += 1 / tied;
  }
  return won / iterations;
}
