import type { CSSProperties } from "react";
import { PERSONALITIES } from "@/ai/bot";
import type { Card, PlayerState } from "@/engine";
import { chips } from "@/lib/format";
import type { Player } from "@/hooks/useGame";
import { PlayingCard } from "./PlayingCard";

interface Props {
  player: Player;
  /** Null when the player is out of chips and not in this hand. */
  state: PlayerState | null;
  stack: number;
  isHuman: boolean;
  isTurn: boolean;
  /** Show the hole cards face up (always for the human; at showdown for others). */
  reveal: boolean;
  /** Seconds to wait before flipping revealed cards (lets an all-in run-out finish first). */
  revealDelay: number;
  winAmount: number;
  winningCards: Set<Card> | null;
  style: CSSProperties;
}

export function Seat({ player, state, stack, isHuman, isTurn, reveal, revealDelay, winAmount, winningCards, style }: Props) {
  const out = state === null;
  const folded = state?.folded ?? false;
  const status = out ? "Out" : state.allIn ? "All-in" : state.lastAction;
  // Cards the engine hasn't revealed (the bot's, before a showdown) are drawn face down.
  const cards: (Card | null)[] = out ? [] : state.hole.length > 0 ? state.hole : [null, null];
  const classes = [
    "seat",
    isHuman ? "seat-human" : "",
    isTurn ? "is-turn" : "",
    folded ? "is-folded" : "",
    out ? "is-out" : "",
    winAmount > 0 ? "is-winner" : "",
  ];

  return (
    <div className={classes.filter(Boolean).join(" ")} style={style}>
      <div className="seat-cards">
        {cards.map((card, i) => (
          <PlayingCard
            key={`${card}-${i}`}
            card={card}
            faceDown={!reveal}
            size={isHuman ? "lg" : "sm"}
            delay={reveal && !isHuman ? revealDelay : i * 0.08}
            highlight={card !== null && winningCards?.has(card)}
            dim={folded || (winningCards !== null && (card === null || !winningCards.has(card)))}
          />
        ))}
      </div>
      <div className="seat-plate">
        <div className="avatar" style={{ "--avatar": player.color } as CSSProperties}>
          {isHuman ? "★" : player.name[0]}
          {isTurn && !isHuman && (
            <span className="thinking" aria-label="Thinking">
              <i />
              <i />
              <i />
            </span>
          )}
        </div>
        <div className="seat-info">
          <div className="seat-name" title={player.opponent ? PERSONALITIES[player.opponent.personality].label : undefined}>
            {player.name}
          </div>
          <div className="seat-stack">{chips(state?.stack ?? stack)}</div>
        </div>
        {status && <div className={`seat-status status-${status.split(" ")[0]!.toLowerCase()}`}>{status}</div>}
      </div>
      {winAmount > 0 && (
        <div className="win-float" style={{ animationDelay: `${revealDelay}s` }}>
          +{chips(winAmount)}
        </div>
      )}
    </div>
  );
}
