import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { Game } from "@/hooks/useGame";
import { ResultBadge } from "./ResultBanner";

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
