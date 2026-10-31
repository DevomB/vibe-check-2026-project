import { type Card, type Suit, isCard, rankOf, suitOf } from "./cards";

export const HandCategory = {
  HighCard: 0,
  Pair: 1,
  TwoPair: 2,
  ThreeOfAKind: 3,
  Straight: 4,
  Flush: 5,
  FullHouse: 6,
  FourOfAKind: 7,
  StraightFlush: 8,
} as const;
export type HandCategory = (typeof HandCategory)[keyof typeof HandCategory];

export const CATEGORY_NAMES: Record<HandCategory, string> = {
  0: "High Card",
  1: "Pair",
  2: "Two Pair",
  3: "Three of a Kind",
  4: "Straight",
  5: "Flush",
  6: "Full House",
  7: "Four of a Kind",
  8: "Straight Flush",
};

export interface HandValue {
  category: HandCategory;
  /** Higher is better. Two hands with the same score tie. */
  score: number;
  /** The five cards that make the hand, most important first. */
  best: Card[];
  /** Description such as "Full House, Kings full of Fives". */
  name: string;
}

const SINGULAR = ["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King", "Ace"];
const PLURAL = ["", "", "Twos", "Threes", "Fours", "Fives", "Sixes", "Sevens", "Eights", "Nines", "Tens", "Jacks", "Queens", "Kings", "Aces"];

/** Packs the category and up to five tiebreak ranks into one comparable number. */
function scoreOf(category: HandCategory, ranks: number[]): number {
  let score = category;
  for (let i = 0; i < 5; i++) score = score * 15 + (ranks[i] ?? 0);
  return score;
}

/** Finds the highest five-card straight among cards sorted by rank (descending). */
function findStraight(sorted: Card[]): Card[] | null {
  const byRank = new Map<number, Card>();
  for (const c of sorted) if (!byRank.has(rankOf(c))) byRank.set(rankOf(c), c);
  for (let high = 14; high >= 5; high--) {
    const run: Card[] = [];
    for (let r = high; r > high - 5; r--) {
      const card = byRank.get(r === 1 ? 14 : r);
      if (!card) break;
      run.push(card);
    }
    if (run.length === 5) return run;
  }
  return null;
}

/** Evaluates the best five-card hand from 5 to 7 cards. */
export function evaluate(cards: readonly Card[]): HandValue {
  if (cards.length < 5 || cards.length > 7) throw new Error(`evaluate needs 5-7 cards, got ${cards.length}`);
  if (!cards.every(isCard) || new Set(cards).size !== cards.length) throw new Error("evaluate needs distinct valid cards");
  const sorted = cards.slice().sort((a, b) => rankOf(b) - rankOf(a));

  const bySuit = new Map<Suit, Card[]>();
  for (const c of sorted) {
    const list = bySuit.get(suitOf(c));
    if (list) list.push(c);
    else bySuit.set(suitOf(c), [c]);
  }
  const flushCards = [...bySuit.values()].find((list) => list.length >= 5);

  if (flushCards) {
    const sf = findStraight(flushCards);
    if (sf) {
      const high = rankOf(sf[1]!) + 1; // sf[0] may be a low ace in A-2-3-4-5
      const name = high === 14 ? "Royal Flush" : `Straight Flush, ${SINGULAR[high]} high`;
      return { category: HandCategory.StraightFlush, score: scoreOf(HandCategory.StraightFlush, [high]), best: sf, name };
    }
  }

  // Group by rank: biggest groups first, then higher rank first.
  const groups = new Map<number, Card[]>();
  for (const c of sorted) {
    const list = groups.get(rankOf(c));
    if (list) list.push(c);
    else groups.set(rankOf(c), [c]);
  }
  const ordered = [...groups.entries()].sort((a, b) => b[1].length - a[1].length || b[0] - a[0]);
  const [top, second] = ordered;
  const kickers = (exclude: number[], n: number) => sorted.filter((c) => !exclude.includes(rankOf(c))).slice(0, n);

  if (top![1].length === 4) {
    const k = kickers([top![0]], 1);
    return {
      category: HandCategory.FourOfAKind,
      score: scoreOf(HandCategory.FourOfAKind, [top![0], rankOf(k[0]!)]),
      best: [...top![1], ...k],
      name: `Four of a Kind, ${PLURAL[top![0]]}`,
    };
  }

  if (top![1].length === 3 && second && second[1].length >= 2) {
    // The pair part is the best remaining group of two or more (it may be a second set of three).
    const pair = ordered.slice(1).filter(([, cs]) => cs.length >= 2).sort((a, b) => b[0] - a[0])[0]!;
    return {
      category: HandCategory.FullHouse,
      score: scoreOf(HandCategory.FullHouse, [top![0], pair[0]]),
      best: [...top![1], ...pair[1].slice(0, 2)],
      name: `Full House, ${PLURAL[top![0]]} full of ${PLURAL[pair[0]]}`,
    };
  }

  if (flushCards) {
    const best = flushCards.slice(0, 5);
    return {
      category: HandCategory.Flush,
      score: scoreOf(HandCategory.Flush, best.map(rankOf)),
      best,
      name: `Flush, ${SINGULAR[rankOf(best[0]!)]} high`,
    };
  }

  const straight = findStraight(sorted);
  if (straight) {
    const high = rankOf(straight[1]!) + 1;
    return {
      category: HandCategory.Straight,
      score: scoreOf(HandCategory.Straight, [high]),
      best: straight,
      name: `Straight, ${SINGULAR[high]} high`,
    };
  }

  if (top![1].length === 3) {
    const k = kickers([top![0]], 2);
    return {
      category: HandCategory.ThreeOfAKind,
      score: scoreOf(HandCategory.ThreeOfAKind, [top![0], ...k.map(rankOf)]),
      best: [...top![1], ...k],
      name: `Three of a Kind, ${PLURAL[top![0]]}`,
    };
  }

  if (top![1].length === 2 && second && second[1].length === 2) {
    const k = kickers([top![0], second[0]], 1);
    return {
      category: HandCategory.TwoPair,
      score: scoreOf(HandCategory.TwoPair, [top![0], second[0], rankOf(k[0]!)]),
      best: [...top![1], ...second[1], ...k],
      name: `Two Pair, ${PLURAL[top![0]]} and ${PLURAL[second[0]]}`,
    };
  }

  if (top![1].length === 2) {
    const k = kickers([top![0]], 3);
    return {
      category: HandCategory.Pair,
      score: scoreOf(HandCategory.Pair, [top![0], ...k.map(rankOf)]),
      best: [...top![1], ...k],
      name: `Pair of ${PLURAL[top![0]]}`,
    };
  }

  const best = sorted.slice(0, 5);
  return {
    category: HandCategory.HighCard,
    score: scoreOf(HandCategory.HighCard, best.map(rankOf)),
    best,
    name: `High Card, ${SINGULAR[rankOf(best[0]!)]}`,
  };
}

/** Positive if `a` beats `b`, negative if `b` wins, 0 for a tie. */
export function compareHands(a: HandValue, b: HandValue): number {
  return a.score - b.score;
}
