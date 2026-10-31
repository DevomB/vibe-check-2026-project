import { describe, expect, it } from "vitest";
import { seededRng } from "./cards";
import { applyAction, startHand } from "./game";
import { handSeed, leanOrderDeck, mixSeed, nextSeed, seededDeck } from "./seeded";
import { createSession, dealNextHand, settleHand } from "./session";

describe("SplitMix64 (same as Engine/Deck.lean)", () => {
  it("matches the published SplitMix64 outputs for seed 0", () => {
    let s = 0n;
    const outputs: bigint[] = [];
    for (let i = 0; i < 3; i++) {
      s = nextSeed(s);
      outputs.push(mixSeed(s));
    }
    expect(outputs).toEqual([0xe220a8397b1dcdafn, 0x6e789e6aa1b965f4n, 0x06c45d188009454fn]);
  });

  it("wraps at 64 bits", () => {
    expect(nextSeed((1n << 64n) - 1n)).toBe(0x9e3779b97f4a7c14n);
  });

  it("derives hand seeds as Engine/Hand.lean does", () => {
    expect(handSeed(42n, 1)).toBe(nextSeed(42n + 1000003n));
    expect(handSeed(42n, 2)).not.toBe(handSeed(42n, 1));
  });
});

describe("seededDeck", () => {
  it("starts from the Lean deck order", () => {
    const deck = leanOrderDeck();
    expect(deck.slice(0, 3)).toEqual(["2c", "3c", "4c"]);
    expect(deck[12]).toBe("Ac");
    expect(deck[51]).toBe("As");
  });

  // The same checks as the #guard lines in Engine/Deck.lean.
  it("is a shuffle of all 52 cards, repeatable per seed", () => {
    const deck = seededDeck(42n);
    expect(deck).toHaveLength(52);
    expect(new Set(deck).size).toBe(52);
    expect(deck).not.toEqual(leanOrderDeck());
    expect(seededDeck(42n)).toEqual(deck);
    expect(seededDeck(43n)).not.toEqual(deck);
  });

  it("deals like the Lean engine: big blind gets cards 1 and 3, button 2 and 4, burn before each street", () => {
    const order = seededDeck(7n);
    // Heads-up, seat 0 on the button (small blind), seat 1 the big blind.
    let hand = startHand(
      [
        { id: "a", name: "A", stack: 500 },
        { id: "b", name: "B", stack: 500 },
      ],
      0,
      { smallBlind: 5, bigBlind: 10 },
      () => 0,
      order,
    );
    expect(hand.players[1]!.hole).toEqual([order[0], order[2]]);
    expect(hand.players[0]!.hole).toEqual([order[1], order[3]]);
    hand = applyAction(hand, { type: "call" });
    hand = applyAction(hand, { type: "check" });
    expect(hand.board).toEqual(order.slice(5, 8)); // order[4] is burned
    hand = applyAction(hand, { type: "check" });
    hand = applyAction(hand, { type: "check" });
    expect(hand.board[3]).toBe(order[9]); // order[8] is burned
    hand = applyAction(hand, { type: "check" });
    hand = applyAction(hand, { type: "check" });
    expect(hand.board[4]).toBe(order[11]); // order[10] is burned
  });

  it("rejects a dealing order that is not a full deck", () => {
    const seats = [
      { id: "a", name: "A", stack: 500 },
      { id: "b", name: "B", stack: 500 },
    ];
    const config = { smallBlind: 5, bigBlind: 10 };
    expect(() => startHand(seats, 0, config, () => 0, seededDeck(1n).slice(1))).toThrow();
    const dup = seededDeck(1n);
    dup[1] = dup[0]!;
    expect(() => startHand(seats, 0, config, () => 0, dup)).toThrow();
    const invalid = seededDeck(1n);
    invalid[0] = "1c" as typeof invalid[number];
    expect(() => startHand(seats, 0, config, () => 0, invalid)).toThrow();
  });
});

describe("replays", () => {
  /** Plays a heads-up game where both players always call or check, from a game seed. */
  function playGame(gameSeed: bigint, hands: number) {
    let session = createSession(
      [
        { id: "you", name: "You", stack: 500 },
        { id: "bot", name: "Bot", stack: 500 },
      ],
      { smallBlind: 5, bigBlind: 10 },
    );
    const results: string[] = [];
    for (let n = 1; n <= hands; n++) {
      const { session: next, dealt } = dealNextHand(session, seededRng(0), seededDeck(handSeed(gameSeed, n)));
      let hand = dealt.hand;
      while (hand.toAct !== null) hand = applyAction(hand, hand.players[hand.toAct]!.streetBet < hand.currentBet ? { type: "call" } : { type: "check" });
      session = settleHand(next, { ...dealt, hand });
      results.push(`${hand.board.join("")} ${session.seats.map((s) => s.stack).join("/")}`);
      if (session.seats.some((s) => s.stack === 0)) break;
    }
    return results;
  }

  it("the same seed replays the same game", () => {
    expect(playGame(2024n, 10)).toEqual(playGame(2024n, 10));
    expect(playGame(2024n, 10)).not.toEqual(playGame(2025n, 10));
  });
});
