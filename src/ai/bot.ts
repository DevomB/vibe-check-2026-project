import type { Rng } from "../engine/cards";
import { type Action, type HandState, type LegalActions, legalActions, potTotal } from "../engine/game";
import { estimateEquity } from "./equity";

/** Playing style knobs, each from 0 to 1. */
export interface Personality {
  label: string;
  /** How willing to call with weaker hands. */
  looseness: number;
  /** How often strong hands are bet or raised rather than checked or called. */
  aggression: number;
  /** How often to bet or raise with a weak hand. */
  bluff: number;
}

export const PERSONALITIES = {
  rock: { label: "Tight & cautious", looseness: 0.1, aggression: 0.3, bluff: 0.02 },
  shark: { label: "Aggressive pro", looseness: 0.35, aggression: 0.8, bluff: 0.15 },
  maniac: { label: "Wild bluffer", looseness: 0.6, aggression: 0.95, bluff: 0.45 },
  station: { label: "Calls everything", looseness: 0.9, aggression: 0.15, bluff: 0.03 },
  pro: { label: "Balanced", looseness: 0.3, aggression: 0.55, bluff: 0.1 },
} satisfies Record<string, Personality>;

export type PersonalityKey = keyof typeof PERSONALITIES;

export interface BotOptions {
  /** Monte Carlo samples per decision (default: 250 before the flop, 400 after). */
  iterations?: number;
}

/* Hand strength is equity divided by a fair share, 1 / (opponents + 1):
   1.0 means an average hand against this many opponents. */

/** Strength needed to bet or raise for value, before the aggression discount. */
const VALUE_STRENGTH = 1.6;
/** How much full aggression lowers the value threshold. */
const AGGRESSION_DISCOUNT = 0.4;
/** Strength at which the bot considers moving all-in. */
const MONSTER_STRENGTH = 2.2;
/** How much full looseness lowers the equity needed to call (as a fraction of pot odds). */
const LOOSE_CALL_DISCOUNT = 0.35;
/** Bluff chance at personality.bluff = 1. */
const MAX_BLUFF_CHANCE = 0.3;
/** Bluffs only make sense against few opponents. */
const MAX_BLUFF_OPPONENTS = 2;
/** Chance a strong hand is slow-played at aggression 0. */
const MAX_SLOWPLAY_CHANCE = 0.35;
/** Bet sizes as fractions of the pot. */
const SMALL_BET = 0.5;
const BIG_BET = 1.0;
/** Push all-in instead of a normal raise when the stack left is this small relative to the pot. */
const SHORT_STACK_POT_RATIO = 0.6;

/**
 * Picks an action for `seat`, whose turn it must be. Uses only what that seat can
 * see: its own cards, the board, bets, stacks and the number of opponents still in.
 * Never mutates `state`. Always returns a legal action.
 */
export function chooseAction(state: HandState, seat: number, personality: Personality, rng: Rng, options: BotOptions = {}): Action {
  if (state.toAct !== seat) throw new Error(`It is not seat ${seat}'s turn`);
  const legal = legalActions(state);
  const me = state.players[seat]!;
  const opponents = state.players.filter((p, j) => j !== seat && !p.folded).length;

  const iterations = options.iterations ?? (state.street === "preflop" ? 250 : 400);
  const equity = estimateEquity(me.hole, state.board, opponents, iterations, rng);
  const strength = equity * (opponents + 1);

  // An all-in caller cannot win the portion of another player's overbet they cannot match.
  const pot = state.players.reduce((sum, p) => sum + Math.min(p.totalBet, me.totalBet + legal.call), 0);
  const potOdds = legal.call > 0 ? legal.call / (pot + legal.call) : 0;
  const valueThreshold = VALUE_STRENGTH - personality.aggression * AGGRESSION_DISCOUNT;
  const bluffing = opponents <= MAX_BLUFF_OPPONENTS && rng() < personality.bluff * MAX_BLUFF_CHANCE;
  const slowplay = rng() < (1 - personality.aggression) * MAX_SLOWPLAY_CHANCE;

  const raise = (fraction: number): Action => ({ type: "raise", to: raiseTo(state, legal, seat, fraction, strength) });

  if (legal.check) {
    if (legal.raise && strength >= valueThreshold && !slowplay) {
      return raise(strength >= MONSTER_STRENGTH ? BIG_BET : SMALL_BET + (BIG_BET - SMALL_BET) * rng());
    }
    if (legal.raise && bluffing) return raise(SMALL_BET);
    return { type: "check" };
  }

  // Facing a bet.
  if (legal.raise && strength >= valueThreshold && equity > potOdds && !slowplay) {
    return raise(strength >= MONSTER_STRENGTH ? BIG_BET : SMALL_BET + (BIG_BET - SMALL_BET) * rng());
  }
  if (legal.raise && bluffing) return raise(BIG_BET);

  const requiredEquity = potOdds * (1 - personality.looseness * LOOSE_CALL_DISCOUNT);
  if (equity >= requiredEquity) return { type: "call" };
  return { type: "fold" };
}

/** A legal raise total about `fraction` of the pot on top of the current bet, in whole chips. */
function raiseTo(state: HandState, legal: LegalActions, seat: number, fraction: number, strength: number): number {
  const { min, max } = legal.raise!;
  const me = state.players[seat]!;
  const potAfterCall = potTotal(state) + legal.call;
  const stackAfterCall = me.stack - legal.call;
  if (strength >= MONSTER_STRENGTH && stackAfterCall <= potAfterCall * SHORT_STACK_POT_RATIO) return max;

  const unit = Math.max(1, state.config.smallBlind);
  const target = Math.round((state.currentBet + potAfterCall * fraction) / unit) * unit;
  return Math.min(max, Math.max(min, target));
}
