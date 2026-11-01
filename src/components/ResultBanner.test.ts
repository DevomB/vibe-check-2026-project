import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { Game, HandGrades } from "@/hooks/useGame";
import type { ReviewDecision, ReviewLabel } from "@/lean/protocol";
import { NextHandBar, ResultBadge } from "./ResultBanner";

function badge(outcome: "player0" | "player1" | "tie" | "fold", names: [string, string], winnings: [number, number]) {
  // Renderer-only fixture: these are the fields ResultBadge reads, not a simulated engine.
  const game = {
    players: [{ name: "You" }, { name: "Bot" }],
    lean: { result: { outcome }, players: names.map(handName => ({ handName })) },
    dealt: {
      seatOf: [0, 1],
      hand: {
        players: [{ folded: false }, { folded: outcome === "fold" }],
        result: { showdown: outcome !== "fold", winnings, pots: [{ winners: outcome === "tie" ? [0, 1] : [outcome === "player1" ? 1 : 0] }] },
      },
    },
  } as unknown as Game;
  return renderToStaticMarkup(createElement(ResultBadge, { game, delay: 0 }));
}

describe("showdown hand names", () => {
  it("names the losing hand in the bluff demo", () => {
    expect(badge("player0", ["Pair", "High Card"], [60, 0])).toContain("Pair beats High Card");
  });

  it("orders the names correctly when the bot wins", () => {
    expect(badge("player1", ["Pair", "Straight"], [0, 180])).toContain("Straight beats Pair");
  });

  it("does not describe a split pot as one hand beating another", () => {
    const html = badge("tie", ["Straight", "Straight"], [30, 30]);
    expect(html).toContain("Split pot");
    expect(html).not.toContain(" beats ");
  });

  it("keeps hand names hidden after a fold", () => {
    const html = badge("fold", ["Pair", "High Card"], [15, 0]);
    expect(html).toContain("Bot folded");
    expect(html).not.toContain("Pair");
    expect(html).not.toContain("High Card");
  });
});

/** A graded call, with only the fields the result bar reads. */
function graded(label: ReviewLabel): ReviewDecision {
  return { street: "flop", your_action: "call", label, worth_bb: null, equity_had: null, equity_needed: null };
}

function bar(grades: HandGrades | null) {
  const game = {} as Game;
  const noop = () => {};
  return renderToStaticMarkup(createElement(NextHandBar, { game, delay: 0, gameOver: false, grades, onNextHand: noop, onReview: noop }));
}

describe("the hand's grades on the result bar", () => {
  it("shows a badge per graded move, in order, and how many there were", () => {
    const html = bar({ hand: 4, decisions: [graded("Best"), graded("Mistake")] });
    expect(html).toContain("2 graded moves");
    expect(html.indexOf("Best")).toBeLessThan(html.indexOf("Mistake"));
  });

  it("says so when Lean graded nothing in the hand", () => {
    expect(bar({ hand: 4, decisions: [] })).toContain("No graded move");
  });

  it("shows nothing before the grades are back", () => {
    const html = bar(null);
    expect(html).not.toContain("graded");
    expect(html).toContain("Next hand");
  });
});
