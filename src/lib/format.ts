import { type Card, rankOf, suitOf } from "./cards";

export const SUIT_SYMBOL = { c: "♣", d: "♦", h: "♥", s: "♠" } as const;

const RANK_NAME = ["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King", "Ace"];
const RANK_PLURAL = ["", "", "Twos", "Threes", "Fours", "Fives", "Sixes", "Sevens", "Eights", "Nines", "Tens", "Jacks", "Queens", "Kings", "Aces"];

export function rankLabel(card: Card): string {
  return card[0] === "T" ? "10" : card[0]!;
}

export function isRed(card: Card): boolean {
  const s = suitOf(card);
  return s === "h" || s === "d";
}

export function cardText(card: Card): string {
  return rankLabel(card) + SUIT_SYMBOL[suitOf(card)];
}

export function chips(n: number): string {
  return n.toLocaleString("en-US");
}

/** "Pocket Kings", "Ace-King suited", "Seven-Two offsuit". */
export function describeStartingHand(hole: readonly Card[]): string {
  const [a, b] = hole;
  if (!a || !b) return "";
  const [hi, lo] = rankOf(a) >= rankOf(b) ? [a, b] : [b, a];
  if (rankOf(hi) === rankOf(lo)) return `Pocket ${RANK_PLURAL[rankOf(hi)]}`;
  return `${RANK_NAME[rankOf(hi)]}-${RANK_NAME[rankOf(lo)]} ${suitOf(hi) === suitOf(lo) ? "suited" : "offsuit"}`;
}
