/**
 * Cards as the screen shows them, in Lean's text form: a rank (2-9, T, J, Q, K, A) and a suit
 * (c, d, h, s), like "Ah". Display helpers only. Lean deals the cards and decides every rule.
 */

export const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"] as const;
export const SUITS = ["c", "d", "h", "s"] as const;

export type RankChar = (typeof RANKS)[number];
export type Suit = (typeof SUITS)[number];
/** A card as rank + suit, e.g. "As" (ace of spades) or "Td" (ten of diamonds). */
export type Card = `${RankChar}${Suit}`;

/** Numeric rank, 2 to 14 with the ace high. Used to name starting hands ("Ace-King suited"). */
export function rankOf(card: Card): number {
  return RANKS.indexOf(card[0] as RankChar) + 2;
}

export function suitOf(card: Card): Suit {
  return card[1] as Suit;
}
