import { type HandState, legalActions } from "../../engine/game";
import type { SliderView, Sliders } from "./decide";

/**
 * The slider bot's view of a hand in the prototype engine (src/engine/game.ts), for the seat whose
 * turn it is. Heads-up only. The pot leaves out any part of the opponent's bet the bot cannot match.
 */
export function sliderView(state: HandState, seat: number, sliders: Sliders, seed: number): SliderView {
  if (state.players.length !== 2) throw new Error("The slider bot plays heads-up only");
  if (state.toAct !== seat) throw new Error(`It is not seat ${seat}'s turn`);
  const legal = legalActions(state);
  const me = state.players[seat]!;
  const pot = state.players.reduce((sum, p) => sum + Math.min(p.totalBet, me.totalBet + legal.call), 0);
  return {
    hole: me.hole,
    board: state.board,
    pot,
    toCall: legal.call,
    streetBet: me.streetBet,
    raise: legal.raise,
    risk: sliders.risk,
    bluffPct: sliders.bluffPct,
    seed,
  };
}
