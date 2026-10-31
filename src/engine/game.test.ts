import { describe, expect, it } from "vitest";
import { type Card, fullDeck, seededRng } from "./cards";
import { type Action, type HandConfig, type HandState, IllegalActionError, applyAction, legalActions, potTotal, startHand } from "./game";

const config: HandConfig = { smallBlind: 5, bigBlind: 10 };

function deal(stacks: number[], button = 0, seed = 1): HandState {
  return startHand(
    stacks.map((stack, i) => ({ id: `p${i}`, name: `P${i}`, stack })),
    button,
    config,
    seededRng(seed),
  );
}

/**
 * Gives each player the hole cards in `holes` and arranges the deck so the board
 * comes out as `board` (with burn cards in between).
 */
function rig(state: HandState, holes: string[][], board: string[]): HandState {
  const used = new Set([...holes.flat(), ...board]);
  const spare = fullDeck().filter((c) => !used.has(c));
  holes.forEach((hole, i) => (state.players[i]!.hole = hole as Card[]));
  const [f1, f2, f3, t, r] = board as Card[];
  const order = [spare[0]!, f1!, f2!, f3!, spare[1]!, t!, spare[2]!, r!]; // order the cards come off the deck
  state.deck = [...spare.slice(3), ...order.reverse()];
  return state;
}

function act(state: HandState, ...actions: Action[]): HandState {
  return actions.reduce((s, a) => applyAction(s, a), state);
}

const fold: Action = { type: "fold" };
const check: Action = { type: "check" };
const call: Action = { type: "call" };
const raise = (to: number): Action => ({ type: "raise", to });

/** Chips on the table: stacks plus the pot while the hand runs, just stacks once it is paid out. */
const totalChips = (s: HandState) => s.players.reduce((sum, p) => sum + p.stack + (s.result ? 0 : p.totalBet), 0);
const stacksAfter = (s: HandState) => s.players.map((p) => p.stack);

describe("starting a hand", () => {
  it("posts blinds left of the button and starts with the player after the big blind", () => {
    const s = deal([1000, 1000, 1000, 1000], 0);
    expect(s.smallBlindSeat).toBe(1);
    expect(s.bigBlindSeat).toBe(2);
    expect(s.players.map((p) => p.streetBet)).toEqual([0, 5, 10, 0]);
    expect(s.toAct).toBe(3);
    expect(s.currentBet).toBe(10);
    expect(s.players.every((p) => p.hole.length === 2)).toBe(true);
    expect(s.deck.length).toBe(52 - 8);
  });

  it("with three players the button acts first", () => {
    expect(deal([1000, 1000, 1000], 1).toAct).toBe(1);
  });

  it("heads-up: the button posts the small blind and acts first before the flop", () => {
    const s = deal([1000, 1000], 0);
    expect(s.smallBlindSeat).toBe(0);
    expect(s.bigBlindSeat).toBe(1);
    expect(s.toAct).toBe(0);
  });

  it("heads-up: the button acts last after the flop", () => {
    const s = act(deal([1000, 1000], 0), call, check);
    expect(s.street).toBe("flop");
    expect(s.board.length).toBe(3);
    expect(s.toAct).toBe(1);
  });

  it("a short big blind posts all-in", () => {
    const s = deal([1000, 1000, 7], 0);
    expect(s.players[2]!.streetBet).toBe(7);
    expect(s.players[2]!.allIn).toBe(true);
    expect(s.currentBet).toBe(10);
    expect(s.toAct).toBe(0);
    expect(legalActions(s).call).toBe(10);
    expect(legalActions(s).raise!.min).toBe(20);
  });

  it("heads-up only calls the amount a short all-in big blind actually posted", () => {
    const s = deal([1000, 7]);
    expect(legalActions(s)).toEqual({ fold: true, check: false, call: 2, raise: null });
  });

  it("if both blinds are all-in heads-up, the board runs out at once", () => {
    const s = deal([3, 100], 0);
    expect(s.result).not.toBeNull();
    expect(s.board.length).toBe(5);
    expect(s.toAct).toBeNull();
    expect(stacksAfter(s).reduce((a, b) => a + b, 0)).toBe(103);
    // The big blind's unmatched 7 chips came back.
    expect(s.events).toContainEqual({ type: "return", seat: 1, amount: 7 });
  });

  it("rejects bad setups", () => {
    expect(() => deal([1000])).toThrow();
    expect(() => deal([1000, 0])).toThrow();
    expect(() => deal([1000, 1000], 2)).toThrow();
  });

  it.each([NaN, Infinity, -1, 0, 0.5, Number.MAX_SAFE_INTEGER + 1])("rejects invalid stack %s", (stack) => {
    expect(() => deal([1000, stack])).toThrow();
  });

  it.each([NaN, 0.5])("rejects non-integer button %s", (button) => {
    expect(() => deal([1000, 1000], button)).toThrow();
  });

  it("rejects setups that overflow chip arithmetic or exhaust the deck", () => {
    expect(() => deal([Number.MAX_SAFE_INTEGER, 1])).toThrow();
    expect(() => deal(Array(23).fill(1000))).toThrow();
  });

  it.each([
    { smallBlind: 0, bigBlind: 10 },
    { smallBlind: 5, bigBlind: NaN },
    { smallBlind: 5, bigBlind: 2 },
    { smallBlind: 0.5, bigBlind: 1 },
  ])("rejects invalid blinds %j", (blinds) => {
    expect(() => startHand([{ id: "a", name: "A", stack: 100 }, { id: "b", name: "B", stack: 100 }], 0, blinds, seededRng(1))).toThrow();
  });

  it("keeps its blind configuration independent from the caller", () => {
    const blinds = { ...config };
    const s = startHand([{ id: "a", name: "A", stack: 100 }, { id: "b", name: "B", stack: 100 }], 0, blinds, seededRng(1));
    blinds.bigBlind = 1000;
    expect(s.config.bigBlind).toBe(10);
  });
});

describe("betting", () => {
  it("gives the big blind the option when everyone limps", () => {
    let s = act(deal([1000, 1000, 1000], 0), call, call);
    expect(s.toAct).toBe(2);
    const legal = legalActions(s);
    expect(legal.check).toBe(true);
    expect(legal.call).toBe(0);
    expect(legal.raise).toEqual({ min: 20, max: 1000 });
    s = act(s, check);
    expect(s.street).toBe("flop");
    expect(s.toAct).toBe(1); // first player left of the button
  });

  it("the minimum raise is the size of the last raise", () => {
    let s = deal([1000, 1000, 1000, 1000], 0);
    expect(legalActions(s).raise!.min).toBe(20);
    s = act(s, raise(30)); // raise by 20
    expect(legalActions(s).raise!.min).toBe(50);
    expect(() => act(s, raise(45))).toThrow(IllegalActionError);
    s = act(s, raise(80)); // raise by 50
    expect(legalActions(s).raise!.min).toBe(130);
  });

  it("allows an all-in raise smaller than the minimum", () => {
    let s = deal([1000, 1000, 1000, 1000], 0);
    s.players[3]!.stack = 15; // a full raise would be to 20
    expect(legalActions(s).raise).toEqual({ min: 15, max: 15 });
    s = act(s, raise(15));
    expect(s.players[3]!.allIn).toBe(true);
    expect(s.currentBet).toBe(15);
    expect(s.minRaise).toBe(10); // a short raise does not change the minimum
    expect(legalActions(s).raise!.min).toBe(25);
  });

  it("a short all-in raise does not reopen betting for players who already acted", () => {
    // 3 players: button 0 acts first, then SB 1, then BB 2 (who has 150 total).
    let s = deal([1000, 1000, 150], 0);
    s = act(s, raise(100), call); // button raises by 90, SB calls
    s = act(s, raise(150)); // BB goes all-in: a raise of only 50
    expect(s.toAct).toBe(0);
    let legal = legalActions(s);
    expect(legal.call).toBe(50);
    expect(legal.raise).toBeNull();
    expect(() => act(s, raise(300))).toThrow(IllegalActionError);
    s = act(s, call);
    legal = legalActions(s);
    expect(s.toAct).toBe(1);
    expect(legal.raise).toBeNull();
    s = act(s, call);
    expect(s.street).toBe("flop");
  });

  it("a short all-in raise still lets players who have not acted raise", () => {
    // 4 players: UTG 3 raises, button 0 goes all-in short; SB and BB have not acted.
    let s = deal([150, 1000, 1000, 1000], 0);
    s = act(s, raise(100), raise(150));
    expect(s.toAct).toBe(1);
    expect(legalActions(s).raise).toEqual({ min: 240, max: 1000 });
    s = act(s, fold);
    expect(legalActions(s).raise).not.toBeNull(); // BB has not acted either
    s = act(s, call);
    expect(s.toAct).toBe(3);
    expect(legalActions(s).raise).toBeNull(); // UTG already acted
  });

  it("cumulative short all-ins reopen betting once a full raise is faced", () => {
    const s = act(deal([150, 200, 1000, 1000]), raise(100), raise(150), raise(200), call);
    expect(s.toAct).toBe(3);
    expect(s.minRaise).toBe(90);
    expect(legalActions(s).raise).toEqual({ min: 290, max: 1000 });
    expect(() => act(s, raise(290))).not.toThrow();
  });

  it("a full raise after a short all-in reopens the betting", () => {
    let s = deal([150, 1000, 1000, 1000], 0);
    s = act(s, raise(100), raise(150), raise(300)); // SB re-raises by 150
    s = act(s, fold);
    expect(s.toAct).toBe(3);
    expect(legalActions(s).raise).not.toBeNull();
  });

  it("cannot raise when every opponent is all-in", () => {
    let s = deal([1000, 1000], 0);
    s.players[1]!.stack = 40; // BB has 50 total
    s = act(s, raise(1000));
    expect(s.toAct).toBe(1);
    s = act(s, call);
    expect(s.result).not.toBeNull();
  });

  it("does not ask a player to act when no one can respond", () => {
    let s = deal([1000, 1000, 1000], 0);
    s.players[0]!.stack = 50;
    s = act(s, raise(50), fold); // button all-in, SB folds
    expect(s.toAct).toBe(2);
    expect(legalActions(s).raise).toBeNull();
    s = act(s, call);
    expect(s.toAct).toBeNull();
    expect(s.board.length).toBe(5);
  });
});

describe("ending a hand", () => {
  it("gives the pot to the last player when everyone else folds", () => {
    const s = act(deal([1000, 1000, 1000], 0), raise(30), fold, fold);
    expect(s.result!.showdown).toBe(false);
    expect(s.result!.hands).toEqual([null, null, null]);
    expect(s.result!.winnings).toEqual([25, 0, 0]); // 10 matched by the raiser + both blinds
    expect(s.board).toEqual([]);
    expect(stacksAfter(s)).toEqual([1015, 995, 990]);
    // The 20 chips no one called came back before the pot was paid.
    expect(s.events).toContainEqual({ type: "return", seat: 0, amount: 20 });
  });

  it("returns the part of an all-in that nobody could call", () => {
    let s = rig(deal([1000, 300], 0), [["2c", "7d"], ["Ah", "Ad"]], ["Ks", "Qs", "9h", "4c", "3d"]);
    s = act(s, raise(1000), call);
    expect(s.events).toContainEqual({ type: "return", seat: 0, amount: 700 });
    expect(stacksAfter(s)).toEqual([700, 600]);
  });

  it("runs out the board after an all-in before the flop", () => {
    let s = rig(deal([500, 500], 0), [["Ah", "Kh"], ["2c", "2d"]], ["Ad", "7s", "9c", "4h", "Jd"]);
    s = act(s, raise(500), call);
    expect(s.street).toBe("showdown");
    expect(s.board).toEqual(["Ad", "7s", "9c", "4h", "Jd"]);
    expect(s.result!.showdown).toBe(true);
    expect(s.result!.hands[0]!.name).toBe("Pair of Aces");
    expect(stacksAfter(s)).toEqual([1000, 0]);
    expect(s.events.filter((e) => e.type === "street").map((e) => e.type === "street" && e.street)).toEqual(["flop", "turn", "river"]);
  });

  it("plays a full hand to a showdown", () => {
    let s = rig(deal([1000, 1000, 1000], 0), [["Ah", "Kh"], ["Qc", "Qd"], ["7s", "2d"]], ["Kd", "8h", "3c", "Ks", "5d"]);
    s = act(s, raise(30), call, fold); // flop: SB 1 first
    expect(s.street).toBe("flop");
    expect(s.toAct).toBe(1);
    s = act(s, check, raise(40), call); // turn
    s = act(s, check, check); // river
    s = act(s, raise(100), fold);
    expect(s.result!.showdown).toBe(false);
    expect(s.result!.winnings).toEqual([0, 150, 0]);
  });

  it("splits the pot on a tie", () => {
    let s = rig(deal([500, 500], 0), [["2c", "3d"], ["4c", "5d"]], ["As", "Ks", "Qs", "Js", "Ts"]);
    s = act(s, call, check, check, check, check, check, check, check);
    expect(s.result!.pots[0]!.winners).toEqual([0, 1]);
    expect(stacksAfter(s)).toEqual([500, 500]);
  });

  it("pays a short stack the main pot and the next best hand the side pot", () => {
    // Seat 0 (50 chips) has the best hand, seat 1 (200) the second best, seat 2 (500) the worst.
    let s = rig(
      deal([50, 200, 500], 0),
      [["Ah", "Ad"], ["Kh", "Kd"], ["7c", "2d"]],
      ["As", "Kc", "9h", "4c", "3d"],
    );
    s = act(s, raise(50), raise(200), call);
    expect(s.result!.pots).toEqual([
      { amount: 150, eligible: [0, 1, 2], winners: [0] },
      { amount: 300, eligible: [1, 2], winners: [1] },
    ]);
    expect(stacksAfter(s)).toEqual([150, 300, 300]);
  });

  it("keeps chips the same in total", () => {
    let s = rig(deal([50, 200, 500], 0), [["Ah", "Ad"], ["Kh", "Kd"], ["7c", "2d"]], ["As", "Kc", "9h", "4c", "3d"]);
    const before = totalChips(s);
    s = act(s, raise(50), raise(200), call);
    expect(totalChips(s)).toBe(before);
    expect(potTotal(s)).toBe(0);
    expect(s.result!.pots.reduce((sum, pot) => sum + pot.amount, 0)).toBe(450);
  });
});

describe("illegal actions", () => {
  it.each([null, undefined, "call"])("rejects malformed action %j without changing the hand", (action) => {
    const s = deal([1000, 1000]);
    const before = structuredClone(s);
    expect(() => applyAction(s, action as unknown as Action)).toThrow(IllegalActionError);
    expect(s).toEqual(before);
  });
  it("rejects an unknown runtime action without advancing or changing the hand", () => {
    const s = deal([1000, 1000]);
    const before = structuredClone(s);
    expect(() => applyAction(s, { type: "dance" } as unknown as Action)).toThrow(IllegalActionError);
    expect(s).toEqual(before);
  });
  it("cannot check facing a bet", () => {
    expect(() => act(deal([1000, 1000, 1000]), check)).toThrow(IllegalActionError);
  });

  it("cannot call when there is nothing to call", () => {
    const s = act(deal([1000, 1000, 1000], 0), call, call);
    expect(() => act(s, call)).toThrow(IllegalActionError);
  });

  it("cannot raise outside the allowed range or by a fraction", () => {
    const s = deal([1000, 1000, 1000]);
    expect(() => act(s, raise(15))).toThrow(IllegalActionError);
    expect(() => act(s, raise(1001))).toThrow(IllegalActionError);
    expect(() => act(s, raise(25.5))).toThrow(IllegalActionError);
  });

  it("cannot act after the hand is over", () => {
    const s = act(deal([1000, 1000, 1000], 0), fold, fold);
    expect(s.toAct).toBeNull();
    expect(() => act(s, check)).toThrow(IllegalActionError);
    expect(legalActions(s)).toEqual({ fold: false, check: false, call: 0, raise: null });
  });

  it("does not change the state it was given", () => {
    const s = deal([1000, 1000, 1000], 0);
    const snapshot = structuredClone(s);
    act(s, raise(30), call, call);
    expect(s).toEqual(snapshot);
  });
});
