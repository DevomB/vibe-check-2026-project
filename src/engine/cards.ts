export const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"] as const;
export const SUITS = ["c", "d", "h", "s"] as const;

export type RankChar = (typeof RANKS)[number];
export type Suit = (typeof SUITS)[number];
/** A card as rank + suit, e.g. "As" (ace of spades) or "Td" (ten of diamonds). */
export type Card = `${RankChar}${Suit}`;

const RANK_VALUE = Object.fromEntries(RANKS.map((r, i) => [r, i + 2])) as Record<RankChar, number>;

/** Numeric rank: 2..14, ace high. */
export function rankOf(card: Card): number {
  return RANK_VALUE[card[0] as RankChar];
}

export function suitOf(card: Card): Suit {
  return card[1] as Suit;
}

export function fullDeck(): Card[] {
  return RANKS.flatMap((r) => SUITS.map((s) => `${r}${s}` as Card));
}

export function isCard(value: unknown): value is Card {
  return typeof value === "string" && value.length === 2 && value[0]! in RANK_VALUE && (SUITS as readonly string[]).includes(value[1]!);
}

/** A random number generator returning floats in [0, 1). */
export type Rng = () => number;

/** Uses the browser's / Node's cryptographic random source. */
export const cryptoRng: Rng = () => {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return buf[0]! / 2 ** 32;
};

/** Small deterministic generator (mulberry32) for tests and replays. */
export function seededRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 2 ** 32;
  };
}

/** Fisher–Yates shuffle; returns a new array. */
export function shuffle<T>(items: readonly T[], rng: Rng): T[] {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}
