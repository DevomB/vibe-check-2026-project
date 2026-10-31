import { describe, expect, it } from "vitest";
import { type Rng, seededRng } from "../../engine/cards";
import { type Action, type HandState, applyAction, legalActions, startHand } from "../../engine/game";
import type { Counts } from "./counts";
import { type SliderDecision, type SliderView, callPays, countsFor, decideSlider, decideWithCounts, potRaiseTarget } from "./decide";
import { sliderView } from "./fromHand";

const CONFIG = { smallBlind: 5, bigBlind: 10 };
const RISKS = Array.from({ length: 101 }, (_, risk) => risk);
const continues = (d: SliderDecision) => d.action.type === "call" || d.action.type === "raise";

/** A flop decision: pot of 100, opponent bets 50, so P = 150 and C = 50. */
function view(changes: Partial<SliderView> = {}): SliderView {
  return {
    hole: ["As", "Kd"],
    board: ["2c", "7d", "Js"],
    pot: 150,
    toCall: 50,
    streetBet: 0,
    raise: { min: 100, max: 450 },
    risk: 50,
    bluffPct: 33,
    seed: 1,
    ...changes,
  };
}

function randomCounts(rng: Rng): Counts {
  return { win: Math.floor(rng() * 1000), tie: Math.floor(rng() * 60), loss: 1 + Math.floor(rng() * 1000) };
}

/**
 * Checks that the Risk values where the bot continues (calls or raises) are 0 up to some value:
 * once it folds at some Risk, it folds at every higher Risk. Returns the continue flag per Risk.
 */
function expectNoFoldBelowACall(v: SliderView, counts: Counts): boolean[] {
  const cont = RISKS.map((risk) => continues(decideWithCounts({ ...v, risk }, counts)));
  const firstFold = cont.indexOf(false);
  if (firstFold >= 0) expect(cont.slice(firstFold)).not.toContain(true);
  return cont;
}

/** A random legal move, mostly checks and calls so hands reach later streets. */
function randomMove(state: HandState, rng: Rng): Action {
  const legal = legalActions(state);
  const moves: Action[] = [{ type: "fold" }];
  if (legal.check) moves.push({ type: "check" }, { type: "check" }, { type: "check" });
  if (legal.call > 0) moves.push({ type: "call" }, { type: "call" }, { type: "call" });
  if (legal.raise) moves.push({ type: "raise", to: legal.raise.min + Math.floor(rng() * (legal.raise.max - legal.raise.min + 1)) });
  return moves[Math.floor(rng() * moves.length)]!;
}

function dealHeadsUp(rng: Rng): HandState {
  const stack = 20 + Math.floor(rng() * 960);
  const seats = [
    { id: "bot", name: "Bot", stack },
    { id: "you", name: "You", stack: 1000 - stack },
  ];
  return startHand(seats, Math.floor(rng() * 2), CONFIG, rng);
}

describe("callPays", () => {
  // A pot-sized bet: the opponent bets 100 into 100, so P = 200 and C = 100.
  it("needs 1/3 wins at Risk 0, 1/2 at Risk 50 and 3/5 at Risk 100 against a pot-sized bet", () => {
    expect(callPays({ win: 1, tie: 0, loss: 2 }, 200, 100, 0)).toBe(true);
    expect(callPays({ win: 1, tie: 0, loss: 2 }, 200, 100, 1)).toBe(false);
    expect(callPays({ win: 1, tie: 0, loss: 1 }, 200, 100, 50)).toBe(true);
    expect(callPays({ win: 1, tie: 0, loss: 1 }, 200, 100, 51)).toBe(false);
    expect(callPays({ win: 3, tie: 0, loss: 2 }, 200, 100, 100)).toBe(true);
    expect(callPays({ win: 59, tie: 0, loss: 41 }, 200, 100, 100)).toBe(false);
  });

  it("calls a guaranteed profitable split at every Risk", () => {
    for (const risk of RISKS) expect(callPays({ win: 0, tie: 10, loss: 0 }, 200, 100, risk)).toBe(true);
  });

  it("never calls when it can only lose", () => {
    for (const risk of RISKS) expect(callPays({ win: 0, tie: 0, loss: 5 }, 200, 100, risk)).toBe(false);
  });

  it("never calls at a higher Risk after folding at a lower one (all small cases)", () => {
    for (let win = 0; win <= 6; win++)
      for (let tie = 0; tie <= 6; tie++)
        for (let loss = 0; loss <= 6; loss++)
          for (let toCall = 1; toCall <= 6; toCall++)
            for (let pot = toCall; pot <= toCall + 8; pot++) {
              const calls = RISKS.map((risk) => callPays({ win, tie, loss }, pot, toCall, risk));
              const firstFold = calls.indexOf(false);
              if (firstFold >= 0) expect(calls.slice(firstFold)).not.toContain(true);
            }
  });
});

describe("bet and raise sizes", () => {
  const strong = { win: 80, tie: 0, loss: 20 }; // 80%

  it("raises pot-sized when facing a bet: pot 100, bet 50, raise to 250", () => {
    expect(potRaiseTarget(view())).toBe(250);
    expect(decideWithCounts(view(), strong).action).toEqual({ type: "raise", to: 250 });
  });

  it("raises pot-sized before the flop from the small blind: 5 in, call 5, raise to 30", () => {
    const d = decideWithCounts(view({ board: [], pot: 15, toCall: 5, streetBet: 5, raise: { min: 20, max: 500 } }), strong);
    expect(d.action).toEqual({ type: "raise", to: 30 });
  });

  it("bets pot-sized when nobody has bet, counting chips already in on this street", () => {
    expect(decideWithCounts(view({ pot: 100, toCall: 0, raise: { min: 10, max: 400 } }), strong).action).toEqual({ type: "raise", to: 100 });
    const bigBlind = decideWithCounts(view({ board: [], pot: 20, toCall: 0, streetBet: 10, raise: { min: 20, max: 500 } }), strong);
    expect(bigBlind.action).toEqual({ type: "raise", to: 30 });
    expect(bigBlind.reason).toMatch(/^Raise to 30/);
  });

  it("keeps sizes inside the legal amounts", () => {
    expect(decideWithCounts(view({ raise: { min: 100, max: 180 } }), strong).action).toEqual({ type: "raise", to: 180 });
    expect(decideWithCounts(view({ pot: 5, toCall: 0, raise: { min: 10, max: 400 } }), strong).action).toEqual({ type: "raise", to: 10 });
  });

  it("raises at exactly 75% but not just under it", () => {
    expect(decideWithCounts(view(), { win: 75, tie: 0, loss: 25 }).rule).toBe("raise");
    expect(decideWithCounts(view(), { win: 749, tie: 0, loss: 251 }).rule).not.toBe("raise");
  });

  it("bets at exactly 65% but not just under it", () => {
    const noBet = view({ pot: 100, toCall: 0, raise: { min: 10, max: 400 } });
    expect(decideWithCounts(noBet, { win: 65, tie: 0, loss: 35 }).rule).toBe("bet");
    expect(decideWithCounts(noBet, { win: 649, tie: 0, loss: 351 }).action).toEqual({ type: "check" });
  });

  it("uses the call/fold rule when 75%+ but raising is not allowed", () => {
    expect(decideWithCounts(view({ raise: null }), strong).action).toEqual({ type: "call" });
    expect(decideWithCounts(view({ raise: null, risk: 100 }), { win: 76, tie: 0, loss: 24 }).action).toEqual({ type: "call" });
  });

  it("checks when no bet is faced and it may not bet", () => {
    expect(decideWithCounts(view({ toCall: 0, raise: null }), strong).action).toEqual({ type: "check" });
  });
});

describe("Risk never turns a fold into a call at the same decision", () => {
  it("holds for 3,000 random decisions and counts, and the test sees real call/fold switches", () => {
    const rng = seededRng(2026);
    let switches = 0;
    for (let k = 0; k < 3000; k++) {
      const toCall = 1 + Math.floor(rng() * 400);
      const max = 50 + Math.floor(rng() * 950);
      const v = view({
        toCall,
        pot: toCall + Math.floor(rng() * 800),
        streetBet: Math.floor(rng() * 100),
        raise: rng() < 0.5 ? null : { min: Math.floor(max / 2), max },
      });
      const cont = expectNoFoldBelowACall(v, randomCounts(rng));
      if (cont.includes(true) && cont.includes(false)) switches++;
    }
    expect(switches).toBeGreaterThan(200);
  });

  it("does not change the action at all when no bet is faced", () => {
    const rng = seededRng(7);
    for (let k = 0; k < 500; k++) {
      const v = view({ toCall: 0, pot: 15 + Math.floor(rng() * 500), raise: rng() < 0.3 ? null : { min: 10, max: 500 } });
      const counts = randomCounts(rng);
      const first = decideWithCounts({ ...v, risk: 0 }, counts).action;
      for (const risk of RISKS) expect(decideWithCounts({ ...v, risk }, counts).action).toEqual(first);
    }
  });

  it("holds at real decisions from dealt hands, where the counts do not depend on Risk", () => {
    const rng = seededRng(99);
    const checked = { preflop: 0, flop: 0, turn: 0, river: 0 };
    const streetOf = ["preflop", "", "", "flop", "turn", "river"] as const;
    for (let h = 0; h < 60; h++) {
      let state = dealHeadsUp(rng);
      while (state.toAct !== null) {
        const street = streetOf[state.board.length] as keyof typeof checked;
        if (legalActions(state).call > 0 && (street !== "turn" || checked.turn < 3)) {
          const v = sliderView(state, state.toAct, { risk: 0, bluffPct: 0 }, h);
          const counts = countsFor(v);
          expect(countsFor({ ...v, risk: 100 })).toEqual(counts);
          expectNoFoldBelowACall(v, counts);
          if (street !== "turn") {
            for (const risk of [0, 50, 100]) {
              expect(decideSlider({ ...v, risk }).action).toEqual(decideWithCounts({ ...v, risk }, counts).action);
            }
          }
          checked[street]++;
        }
        state = applyAction(state, randomMove(state, rng));
      }
    }
    for (const n of Object.values(checked)) expect(n).toBeGreaterThan(0);
  }, 60_000);
});

describe("legal moves only", () => {
  /** True if the prototype engine allows `action` now. */
  function isLegal(state: HandState, action: Action): boolean {
    const legal = legalActions(state);
    switch (action.type) {
      case "fold":
        return legal.fold;
      case "check":
        return legal.check;
      case "call":
        return legal.call > 0;
      case "raise":
        return legal.raise !== null && action.to >= legal.raise.min && action.to <= legal.raise.max;
    }
  }

  function playHand(rng: Rng, decide: (state: HandState, seat: number) => SliderDecision) {
    let state = dealHeadsUp(rng);
    while (state.toAct !== null) {
      const { action } = decide(state, state.toAct);
      expect(isLegal(state, action)).toBe(true);
      state = applyAction(state, action);
      if (state.toAct !== null) expect(state.players.reduce((sum, p) => sum + p.stack + p.totalBet, 0)).toBe(1000);
    }
    expect(state.players.reduce((sum, p) => sum + p.stack, 0)).toBe(1000);
  }

  it("picks a legal action in 500 hands between two bots, for any counts and sliders", () => {
    const rng = seededRng(5);
    for (let h = 0; h < 500; h++) {
      const sliders = [0, 1].map(() => ({ risk: Math.floor(rng() * 101), bluffPct: Math.floor(rng() * 61) }));
      playHand(rng, (state, seat) => decideWithCounts(sliderView(state, seat, sliders[seat]!, h), randomCounts(rng)));
    }
  });

  it("picks a legal action in full hands with the real counts", () => {
    const rng = seededRng(6);
    for (let h = 0; h < 6; h++) {
      playHand(rng, (state, seat) => decideSlider(sliderView(state, seat, { risk: 20 + 60 * seat, bluffPct: 33 }, h)));
    }
  }, 60_000);
});

describe("the river", () => {
  const river = view({ hole: ["As", "Ks"], board: ["Qs", "Js", "Ts", "2d", "3c"] });

  it("uses exact counts when facing a bet: the only royal flush raises", () => {
    const d = decideSlider(river);
    expect(d.counts).toEqual({ win: 990, tie: 0, loss: 0 });
    expect(d.action).toEqual({ type: "raise", to: 250 });
  });

  it("checks when no bet is faced, unless given the river betting rule", () => {
    const noBet = { ...river, pot: 100, toCall: 0 };
    expect(decideSlider(noBet).action).toEqual({ type: "check" });
    expect(decideSlider(noBet, { riverOpening: () => ({ type: "raise", to: 100 }) }).action).toEqual({ type: "raise", to: 100 });
  });
});

describe("input checks", () => {
  const counts = { win: 1, tie: 0, loss: 1 };

  it("rejects sliders out of range", () => {
    expect(() => decideWithCounts(view({ risk: 101 }), counts)).toThrow();
    expect(() => decideWithCounts(view({ risk: 2.5 }), counts)).toThrow();
    expect(() => decideWithCounts(view({ bluffPct: 61 }), counts)).toThrow();
  });

  it("rejects a pot smaller than the call, repeated cards and empty counts", () => {
    expect(() => decideWithCounts(view({ pot: 40 }), counts)).toThrow();
    expect(() => decideWithCounts(view({ board: ["As", "7d", "Js"] }), counts)).toThrow();
    expect(() => decideWithCounts(view(), { win: 0, tie: 0, loss: 0 })).toThrow();
  });
});
