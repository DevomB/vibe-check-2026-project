import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { HandGrades } from "@/hooks/useGame";
import type { ReviewDecision, ReviewLabel } from "@/lean/protocol";
import { GameOver } from "./GameOver";

/** A graded fold, with only the fields Game Over reads. */
function graded(label: ReviewLabel): ReviewDecision {
  return { street: "river", your_action: "fold", label, worth_bb: null, equity_had: null, equity_needed: null };
}

function gameOver(grades?: HandGrades[]) {
  const noop = () => {};
  return renderToStaticMarkup(
    createElement(GameOver, {
      won: false,
      stats: { handsPlayed: 3, handsWon: 1, biggestPot: 40 },
      grades,
      delay: 0,
      seed: 7n,
      replay: { sliders: { risk: 50, bluffPct: 20 }, turnMode: "exact", engineCommit: "abc", serverCommit: "def" },
      onAgain: noop,
      onReplay: noop,
      onReview: noop,
      onLobby: noop,
    }),
  );
}

describe("Game Over's score from Lean's grades", () => {
  it("counts the graded moves across hands, and how many were Best or Good", () => {
    const html = gameOver([
      { hand: 1, decisions: [graded("Best"), graded("Good")] },
      { hand: 2, decisions: [] },
      { hand: 3, decisions: [graded("Blunder")] },
    ]);
    expect(html).toContain("<b>2</b> of your 3 graded moves were Best or Good");
  });

  it("shows no score when nothing was graded", () => {
    expect(gameOver([{ hand: 1, decisions: [] }])).not.toContain("graded");
    expect(gameOver()).not.toContain("graded");
  });
});
