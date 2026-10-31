import type { CSSProperties } from "react";
import { type Card, potTotal } from "@/engine";
import { chips } from "@/lib/format";
import { HUMAN_SEAT, type Game } from "@/hooks/useGame";
import { ChipStack } from "./Chips";
import { CardSlot, PlayingCard } from "./PlayingCard";
import { ResultBadge } from "./ResultBanner";
import { Seat } from "./Seat";

/** Seconds between streets when the remaining board is dealt at once (all-in run-out). */
const RUNOUT_STEP = 0.9;

/** Point on the table's oval, as percentages; seat k of n, human (k = 0) at the bottom, play going clockwise. */
function ovalPoint(k: number, n: number, radius: number): CSSProperties {
  const angle = ((90 + (k * 360) / n) * Math.PI) / 180;
  return { left: `${50 + 50 * radius * Math.cos(angle)}%`, top: `${50 + 50 * radius * Math.sin(angle)}%` };
}

/** Animation delay for each board card, so a run-out deals flop, turn and river one after another. */
function boardDelays(boardBefore: number, boardNow: number): number[] {
  const streetOf = (i: number) => (i < 3 ? 0 : i - 2);
  const firstNewStreet = boardBefore < boardNow ? streetOf(boardBefore) : 0;
  return Array.from({ length: boardNow }, (_, i) => {
    if (i < boardBefore) return 0;
    const step = streetOf(i) - firstNewStreet;
    const withinFlop = i < 3 ? (i - boardBefore) * 0.12 : 0;
    return step * RUNOUT_STEP + Math.max(0, withinFlop);
  });
}

/** Seconds until a finished hand's result should appear: after any run-out cards have been dealt. */
export function resultDelay(game: Game): number {
  const delays = boardDelays(game.boardBefore, game.dealt.hand.board.length);
  return Math.max(0, ...delays) + 0.3;
}

/** `botThinking`: the bot's reply is being held back, so show the bot as the one to act. */
export function Table({ game, botThinking = false }: { game: Game; botThinking?: boolean }) {
  const { hand, seatOf } = game.dealt;
  const n = game.players.length;
  const result = hand.result;
  const delays = boardDelays(game.boardBefore, hand.board.length);
  const revealDelay = result ? resultDelay(game) : 0;

  // Highlight the five cards of the winning hand at showdown, as Lean reports them. A split
  // pot's winners hold equal hands, so the first winner's cards are enough.
  let winningCards: Set<Card> | null = null;
  if (result?.showdown) {
    const best = result.winnings
      .map((amount, i) => (amount > 0 ? game.lean.players[seatOf[i]!]!.bestCards : null))
      .find((cards) => cards !== null);
    if (best) winningCards = new Set(best);
  }

  const collected = hand.players.reduce((sum, p) => sum + p.totalBet - p.streetBet, 0);
  const buttonSeat = seatOf[hand.button]!;

  return (
    <div className="table-area">
      <div className="table">
        <div className="table-rail" />
        <div className="table-felt">
          <div className="felt-mark">TEXAS HOLD'EM</div>
          <div className="board">
            {Array.from({ length: 5 }, (_, i) => {
              const card = hand.board[i];
              return card ? (
                <PlayingCard
                  key={`${card}-${game.session.handNumber}`}
                  card={card}
                  size="md"
                  delay={delays[i]}
                  highlight={winningCards?.has(card)}
                  dim={winningCards !== null && !winningCards.has(card)}
                />
              ) : (
                <CardSlot key={`slot-${i}`} />
              );
            })}
          </div>
          <div className="pot">
            {result ? (
              <ResultBadge game={game} delay={revealDelay} />
            ) : collected > 0 ? (
              <ChipStack amount={collected} label="Pot" />
            ) : (
              <span className="pot-label">Pot {chips(potTotal(hand))}</span>
            )}
          </div>
        </div>

        {game.players.map((player, seat) => {
          const index = seatOf.indexOf(seat);
          const state = index >= 0 ? hand.players[index]! : null;
          const isHuman = seat === HUMAN_SEAT;
          const reveal = isHuman || (!!result?.showdown && !!state && !state.folded);
          return (
            <Seat
              key={seat}
              player={player}
              state={state}
              stack={game.session.seats[seat]!.stack}
              isHuman={isHuman}
              isTurn={index >= 0 && (botThinking ? !isHuman : hand.toAct === index)}
              reveal={reveal}
              revealDelay={isHuman ? 0 : revealDelay}
              winAmount={index >= 0 ? (result?.winnings[index] ?? 0) : 0}
              winningCards={winningCards}
              style={ovalPoint(seat, n, 1)}
            />
          );
        })}

        {hand.players.map((p, index) => {
          const seat = seatOf[index]!;
          return p.streetBet > 0 && !result ? (
            <div key={`bet-${seat}`} className="bet" style={ovalPoint(seat, n, 0.56)}>
              <ChipStack amount={p.streetBet} />
            </div>
          ) : null;
        })}

        <div className="dealer-button" style={ovalPoint(buttonSeat + (n * 22) / 360, n, 0.7)} title="Dealer button">
          D
        </div>
      </div>
    </div>
  );
}
