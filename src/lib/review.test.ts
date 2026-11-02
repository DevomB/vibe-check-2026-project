import { describe, expect, it } from "vitest";
import type { LeanEvent, LeanHands, LeanReview, ReviewDecision } from "@/lean/protocol";
import { describeEvents } from "@/hooks/useGame";
import {
  ANY_HAND_NOTE,
  LABELS,
  boardAt,
  buildMoveList,
  formatBb,
  formatPct,
  gradedCoach,
  handsVerdict,
  isRiverSetGrade,
  labelCounts,
  moveCoach,
  movesFromReview,
  noGradeReason,
  selectableMoves,
  streetAt,
} from "./review";

// Practice "Catch a bluff" (seed 1, Risk 0, Bluff 60%): Lean's events from new_game through the
// river call, as the replies sent them, and the review's decisions.
const EVENTS: LeanEvent[] = [
  { type: "blind", player: 0, amount: 5, kind: "small" },
  { type: "blind", player: 1, amount: 10, kind: "big" },
  { type: "action", player: 0, action: "call", amount: 5, allIn: false },
  { type: "action", player: 1, action: "check", amount: 0, allIn: false },
  { type: "street", street: "flop", cards: ["4h", "Qh", "7c"] },
  { type: "action", player: 1, action: "check", amount: 0, allIn: false },
  { type: "action", player: 0, action: "check", amount: 0, allIn: false },
  { type: "street", street: "turn", cards: ["Tc"] },
  { type: "action", player: 1, action: "check", amount: 0, allIn: false },
  { type: "action", player: 0, action: "check", amount: 0, allIn: false },
  { type: "street", street: "river", cards: ["8d"] },
  { type: "action", player: 1, action: "raise", amount: 20, allIn: false, to: 20 },
  { type: "action", player: 0, action: "call", amount: 20, allIn: false },
  { type: "win", player: 0, amount: 60 },
];

const ungraded = (street: ReviewDecision["street"], your_action: ReviewDecision["your_action"]): ReviewDecision => ({
  street,
  your_action,
  label: null,
  worth_bb: null,
  equity_had: null,
  equity_needed: null,
});

const RIVER_CALL: ReviewDecision = {
  street: "river",
  your_action: "call",
  label: "Best",
  worth_bb: { call: 1.57, fold: 0 },
  equity_had: 0.596,
  equity_needed: 0.333,
  range: { value: 324, bluffs: 486, blocked: 51, beat: 452, tie: 0, lose: 307 },
};

const REVIEW: LeanReview = {
  hand: 1,
  decisions: [ungraded("preflop", "call"), ungraded("flop", "check"), ungraded("turn", "check"), RIVER_CALL],
  bot_reasons: ["Check: a", "Check: b", "Check: c", "Bet 20: a bluff, picked at Bluff 60%."],
};

const NAMES = ["You", "Vex"];
const lines = (events: LeanEvent[]) => describeEvents(events, NAMES, 0);

describe("buildMoveList", () => {
  const streets = buildMoveList(EVENTS, lines(EVENTS), REVIEW, 0)!;

  it("groups Lean's events by street, with the cards each street dealt", () => {
    expect(streets.map((s) => [s.street, s.cards.join(" ")])).toEqual([
      ["preflop", ""],
      ["flop", "4h Qh 7c"],
      ["turn", "Tc"],
      ["river", "8d"],
    ]);
    expect(streets[0]!.rows.map((r) => r.text)).toEqual([
      "You post the small blind (5)",
      "Vex posts the big blind (10)",
      "You call 5",
      "Vex checks",
    ]);
    expect(streets[3]!.rows.map((r) => r.text)).toEqual(["Vex bets 20", "You call 20", "You win 60"]);
  });

  it("matches your n-th move with the review's n-th decision, and numbers the bot's moves", () => {
    const moves = selectableMoves(streets);
    expect(moves.map((m) => m.text)).toEqual(["You call 5", "Vex checks", "Vex checks", "You check", "Vex checks", "You check", "Vex bets 20", "You call 20"]);
    const yours = moves.filter((m) => m.player === 0);
    expect(yours.map((m) => m.decision)).toEqual(REVIEW.decisions);
    expect(moves.filter((m) => m.player === 1).map((m) => m.botMove)).toEqual([0, 1, 2, 3]);
    // Only the river call carries a label.
    expect(moves.filter((m) => m.decision?.label).map((m) => m.text)).toEqual(["You call 20"]);
  });

  it("returns null when your moves and the review's decisions do not line up", () => {
    const missing = EVENTS.slice(0, -2);
    expect(buildMoveList(missing, lines(missing), REVIEW, 0)).toBeNull();
    expect(buildMoveList(EVENTS, lines(EVENTS).slice(1), REVIEW, 0)).toBeNull();
  });

  it("leaves the bot's moves unnumbered when its reasons do not match its moves", () => {
    const odd = buildMoveList(EVENTS, lines(EVENTS), { ...REVIEW, bot_reasons: ["only one"] }, 0)!;
    expect(selectableMoves(odd).every((m) => m.botMove === null)).toBe(true);
  });

  it("shows the board as it was at each move", () => {
    const moves = selectableMoves(streets);
    const flopCheck = moves[2]!;
    expect(boardAt(streets, flopCheck.at)).toEqual(["4h", "Qh", "7c"]);
    expect(streetAt(streets, flopCheck.at)).toBe("flop");
    expect(boardAt(streets, moves[0]!.at)).toEqual([]);
    expect(streetAt(streets, moves[0]!.at)).toBe("preflop");
    expect(boardAt(streets, null)).toEqual(["4h", "Qh", "7c", "Tc", "8d"]);
    expect(streetAt(streets, null)).toBe("river");
  });
});

describe("movesFromReview", () => {
  it("lists your moves by street when the events are missing", () => {
    const streets = movesFromReview(REVIEW, 0);
    expect(streets.map((s) => [s.street, s.rows.map((r) => r.text)])).toEqual([
      ["preflop", ["You call"]],
      ["flop", ["You check"]],
      ["turn", ["You check"]],
      ["river", ["You call"]],
    ]);
  });
});

describe("gradedCoach", () => {
  it("words a Best call with Lean's numbers", () => {
    expect(gradedCoach(RIVER_CALL)).toEqual({
      headline: "Calling is Best.",
      chances: "You win 59.6% against the hands the bot bets here (a tie counts half). Calling needed 33.3% to break even.",
      better: null,
      worths: "Calling was worth +1.57 BB; folding was worth 0.00 BB.",
      band: "Best: worth as much as the best choice.",
      note: null,
    });
  });

  it("says what an any-hand grade assumes, and that it is not proved", () => {
    const turnFold: ReviewDecision = { ...RIVER_CALL, street: "turn", your_action: "fold", label: "Mistake", model: "any-hand", equity_had: 0.42, equity_needed: 0.25 };
    const c = gradedCoach(turnFold)!;
    expect(c.chances).toBe("You win 42.0% against any two cards the bot could hold (a tie counts half). Calling needed 25.0% to break even.");
    expect(c.note).toBe(ANY_HAND_NOTE);
    expect(c.note).toMatch(/not proved in Lean\.$/);
    expect(gradedCoach({ ...turnFold, street: "flop" })!.note).toMatch(/1,000 random deals, so it is an estimate\.$/);
    expect(isRiverSetGrade(turnFold)).toBe(false);
    // An engine without the field graded only the river set.
    expect(isRiverSetGrade(RIVER_CALL)).toBe(true);
    expect(isRiverSetGrade({ ...RIVER_CALL, model: "river-set" })).toBe(true);
    expect(isRiverSetGrade(ungraded("river", "call"))).toBe(false);
  });

  it("names the other choice as Best when yours was not", () => {
    const badCall: ReviewDecision = { ...RIVER_CALL, label: "Mistake", worth_bb: { call: -2.67, fold: 0 }, equity_had: 0.185 };
    const c = gradedCoach(badCall)!;
    expect(c.headline).toBe("Calling is a Mistake.");
    expect(c.better).toBe("Folding was Best.");
    expect(c.worths).toBe("Calling was worth −2.67 BB; folding was worth 0.00 BB.");
    expect(c.band).toBe("Mistake: 2 to 5 big blinds worse than the best choice.");
    const badFold: ReviewDecision = { ...RIVER_CALL, your_action: "fold", label: "Inaccuracy" };
    expect(gradedCoach(badFold)).toMatchObject({ headline: "Folding is an Inaccuracy.", better: "Calling was Best." });
  });

  it("does not infer an exact tie from rounded worths", () => {
    // A positive call EV below 0.005 BB also arrives as 0.00; its Best label stays exact.
    const rounded: ReviewDecision = { ...RIVER_CALL, worth_bb: { call: 0, fold: 0 }, equity_had: 0.333 };
    expect(gradedCoach(rounded)!.better).toBeNull();
    expect(gradedCoach({ ...rounded, label: "Good" })!.better).toBe("Folding was Best.");
  });

  it("gives nothing for a move without a grade", () => {
    expect(gradedCoach(ungraded("river", "call"))).toBeNull();
  });
});

describe("numbers", () => {
  it("keeps Lean's two decimals, so a small loss does not round to zero", () => {
    expect(formatBb(0.01)).toBe("+0.01 BB");
    expect(formatBb(-0.04)).toBe("−0.04 BB");
    expect(formatBb(0)).toBe("0.00 BB");
    expect(formatBb(-0.001)).toBe("0.00 BB");
    expect(formatBb(-2.67)).toBe("−2.67 BB");
  });

  it("shows chances with one decimal", () => {
    expect(formatPct(0.185)).toBe("18.5%");
    expect(formatPct(1 / 3)).toBe("33.3%");
    expect(formatPct(1)).toBe("100.0%");
  });
});

describe("labels", () => {
  it("lists the five labels best first, each with its own mark", () => {
    expect(LABELS.map((l) => `${l.glyph} ${l.label}`)).toEqual(["★ Best", "! Good", "?! Inaccuracy", "? Mistake", "?? Blunder"]);
  });

  it("counts the labels of a hand", () => {
    expect(labelCounts(REVIEW.decisions).map((c) => c.count)).toEqual([1, 0, 0, 0, 0]);
  });
});

describe("noGradeReason", () => {
  const reason = (why: string) => `Lean grades your calls and folds when you face a bet. ${why}`;
  const blinds = EVENTS.slice(0, 2);
  const act = (player: number, action: "check" | "call" | "raise" | "fold", amount = 0): LeanEvent => ({ type: "action", player, action, amount, allIn: false });

  it("says when you made no move", () => {
    // You are the big blind, and the bot folds its small blind.
    const botFolds: LeanEvent[] = [{ type: "blind", player: 1, amount: 5, kind: "small" }, { type: "blind", player: 0, amount: 10, kind: "big" }, act(1, "fold"), { type: "win", player: 0, amount: 15 }];
    expect(noGradeReason(botFolds, 0)).toBe(reason("You made no move in this hand."));
  });

  it("says when you never faced a bet", () => {
    // You are the big blind: the bot calls, then everyone checks to the end.
    const checkedDown: LeanEvent[] = [
      { type: "blind", player: 1, amount: 5, kind: "small" },
      { type: "blind", player: 0, amount: 10, kind: "big" },
      act(1, "call", 5),
      act(0, "check"),
      ...EVENTS.filter((e) => e.type === "street").flatMap((street) => [street, act(0, "check"), act(1, "check")]),
    ];
    expect(noGradeReason(checkedDown, 0)).toBe(reason("You never faced a bet in this hand."));
  });

  it("says when you raised the bets you faced", () => {
    // You raise the big blind from the small blind, and the bot folds.
    expect(noGradeReason([...blinds, act(0, "raise", 25), act(1, "fold")], 0)).toBe(reason("You raised the bets you faced instead of calling or folding."));
  });

  it("falls back when the events are not known, or the hand had a call or fold that faced a bet", () => {
    expect(noGradeReason(null, 0)).toBe(reason("This hand had no such decision."));
    expect(noGradeReason(EVENTS, 0)).toBe(reason("This hand had no such decision."));
  });
});

describe("the hands in a review", () => {
  const tripsOnBoard = {
    board: ["7c", "7d", "7h", "Ks", "2c"],
    you: { cards: ["9c", "4d"], hand: "Three of a Kind", best: ["7c", "7d", "7h", "Ks", "9c"], cards_used: 1 },
    bot: { cards: ["Kh", "Kd"], hand: "Full House", best: ["7c", "7d", "7h", "Kh", "Kd"], cards_used: 2 },
    stronger: "bot",
  } as LeanHands;

  it("names both hands and who was stronger", () => {
    expect(handsVerdict(tripsOnBoard, "Mia")).toBe("Mia's full house was stronger than your three of a kind.");
  });

  it("says when the board alone made your hand", () => {
    const boardPlays = { ...tripsOnBoard, you: { ...tripsOnBoard.you, best: ["7c", "7d", "7h", "Ks", "2c"], cards_used: 0 } } as LeanHands;
    expect(handsVerdict(boardPlays, "Mia")).toBe(
      "Mia's full house was stronger than your three of a kind. Your three of a kind was all on the board, so Mia had it too: your own cards did not play.",
    );
  });

  it("uses starting hands before the flop", () => {
    const preflop = {
      board: [],
      you: { cards: ["7d", "2s"], hand: null, best: null, cards_used: 0 },
      bot: { cards: ["Ts", "Ks"], hand: null, best: null, cards_used: 0 },
      stronger: null,
    } as LeanHands;
    expect(handsVerdict(preflop, "Mia")).toBe("Before the flop: you held Seven-Two offsuit, Mia held King-Ten suited.");
  });
});

describe("the pot-odds check on your other moves", () => {
  const base = { street: "flop", label: null, worth_bb: null, equity_had: null, equity_needed: null, hand_then: "Pair" } as const;

  it("calls a call sound when the hand wins more often than the price", () => {
    const c = moveCoach({ ...base, your_action: "call", win_chance: 0.62, price: 0.25 }, ["Kc", "9d"])!;
    expect(c.held).toBe("You held a Pair: about 62% to win against a random hand.");
    expect(c.sound).toBe(true);
  });

  it("flags a fold that gave up a good price", () => {
    const c = moveCoach({ ...base, your_action: "fold", win_chance: 0.62, price: 0.25 }, ["Kc", "9d"])!;
    expect(c.verdict).toBe("A call cost 25% of the pot after calling, less than your hand's chances: folding gave up a good price.");
    expect(c.sound).toBe(false);
  });

  it("says nothing it cannot back up when there was no price", () => {
    const c = moveCoach({ ...base, your_action: "check", win_chance: 0.4, price: null }, ["Kc", "9d"])!;
    expect(c.verdict).toBeNull();
  });
});
