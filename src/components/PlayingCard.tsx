import type { CSSProperties } from "react";
import { type Card, suitOf } from "@/lib/cards";
import { SUIT_SYMBOL, cardText, isRed, rankLabel } from "@/lib/format";

interface Props {
  card: Card | null;
  faceDown?: boolean;
  size?: "sm" | "md" | "lg";
  /** Part of the winning five cards. */
  highlight?: boolean;
  /** Not part of the winning hand, or folded. */
  dim?: boolean;
  /** Seconds before the deal-in animation (and flip) starts. */
  delay?: number;
}

/** A playing card that can flip between its back and its face. */
export function PlayingCard({ card, faceDown = false, size = "md", highlight, dim, delay = 0 }: Props) {
  const showFace = card !== null && !faceDown;
  const classes = ["card", `card-${size}`, showFace ? "" : "is-down", highlight ? "is-highlight" : "", dim ? "is-dim" : ""];
  const style = { "--delay": `${delay}s` } as CSSProperties;
  return (
    <div className={classes.filter(Boolean).join(" ")} style={style} aria-label={showFace ? cardText(card) : "Face-down card"}>
      <div className="card-inner">
        <div className={`card-face card-front ${card && isRed(card) ? "red" : "black"}`}>
          {card && (
            <>
              <span className="card-corner top">
                <span className="card-rank">{rankLabel(card)}</span>
                <span className="card-suit">{SUIT_SYMBOL[suitOf(card)]}</span>
              </span>
              <span className="card-pip">{SUIT_SYMBOL[suitOf(card)]}</span>
              <span className="card-corner bottom">
                <span className="card-rank">{rankLabel(card)}</span>
                <span className="card-suit">{SUIT_SYMBOL[suitOf(card)]}</span>
              </span>
            </>
          )}
        </div>
        <div className="card-face card-back" />
      </div>
    </div>
  );
}

/** An empty spot on the board where a card will be dealt. */
export function CardSlot({ size = "md" }: { size?: "sm" | "md" | "lg" }) {
  return <div className={`card-slot card-${size}`} />;
}
