import type { Card } from "./cards";

/**
 * Seeded dealing that matches the Lean engine (`Engine/Deck.lean`) card for card:
 * the same game seed gives the same hands in both, so games can be replayed and the
 * two engines compared.
 */

const MASK_64 = (1n << 64n) - 1n;

/** The next generator state (SplitMix64), as `nextSeed` in Engine/Deck.lean. */
export function nextSeed(s: bigint): bigint {
  return (s + 0x9e3779b97f4a7c15n) & MASK_64;
}

/** Turns a generator state into a random-looking number, as `mixSeed` in Engine/Deck.lean. */
export function mixSeed(s: bigint): bigint {
  let z = ((s ^ (s >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK_64;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK_64;
  return z ^ (z >> 31n);
}

/** The seed for hand number `handNumber` (1, 2, ...) of a game, as `handSeed` in Engine/Hand.lean. */
export function handSeed(gameSeed: bigint, handNumber: number): bigint {
  return nextSeed(gameSeed + BigInt(handNumber) * 1000003n);
}

/** A new deck in the Lean engine's order: clubs, diamonds, hearts, spades, each from 2 up to ace. */
export function leanOrderDeck(): Card[] {
  return (["c", "d", "h", "s"] as const).flatMap((suit) => [..."23456789TJQKA"].map((rank) => `${rank}${suit}` as Card));
}

/**
 * The shuffled deck for a seed, top card first, as `shuffle seed fullDeck` in Engine/Deck.lean:
 * each step advances the generator and takes the card at `mix % cardsLeft` from what is left.
 */
export function seededDeck(seed: bigint): Card[] {
  const left = leanOrderDeck();
  const deck: Card[] = [];
  let s = seed;
  while (left.length > 0) {
    s = nextSeed(s);
    const i = Number(mixSeed(s) % BigInt(left.length));
    deck.push(left.splice(i, 1)[0]!);
  }
  return deck;
}

/** A new random game seed (32 bits, so it is easy to read out and type back in). */
export function randomGameSeed(): bigint {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return BigInt(buf[0]!);
}
