import { useEffect, useRef } from "react";
import { type Card, suitOf } from "@/lib/cards";
import { SUIT_SYMBOL, isRed, rankLabel } from "@/lib/format";
import type { StreetMoves } from "@/lib/review";
import { ReviewBadge } from "./ReviewBadge";
import styles from "./review.module.css";

interface Props {
  streets: StreetMoves[];
  /** The selected move's place in the hand's events, or null for the start. */
  selected: number | null;
  onSelect: (at: number) => void;
  human: number;
}

const STREET_NAME: Record<StreetMoves["street"], string> = { preflop: "Preflop", flop: "Flop", turn: "Turn", river: "River" };

function MiniCard({ card }: { card: Card }) {
  return (
    <span className={`${styles.miniCard} ${isRed(card) ? styles.red : ""}`}>
      {rankLabel(card)}
      {SUIT_SYMBOL[suitOf(card)]}
    </span>
  );
}

/**
 * Every move of the hand in order, by street, the bot's and yours, like a chess move list.
 * Graded moves carry their badge; the others carry none. Click a move to look at it.
 */
export function MoveList({ streets, selected, onSelect, human }: Props) {
  const listRef = useRef<HTMLDivElement>(null);
  // Keep the selected move in view while stepping with the arrow keys.
  useEffect(() => {
    const el = listRef.current?.querySelector<HTMLElement>('[aria-current="true"]');
    el?.scrollIntoView({ block: "nearest" });
  }, [selected]);

  return (
    <div className={styles.moveList} ref={listRef}>
      {streets.map((s) => (
        <section key={`${s.street}-${s.dealtAt}`} className={styles.street}>
          <h4 className={styles.streetHead}>
            <span>{STREET_NAME[s.street]}</span>
            {s.cards.length > 0 && (
              <span className={styles.streetCards}>
                {s.cards.map((c) => (
                  <MiniCard key={c} card={c} />
                ))}
              </span>
            )}
          </h4>
          {s.rows.length === 0 && <p className={styles.moveNote}>No betting: a player was all-in.</p>}
          <ol className={styles.moves}>
            {s.rows.map((r) =>
              r.kind === "move" ? (
                <li key={r.at}>
                  <button
                    type="button"
                    className={`${styles.move} ${r.player === human ? styles.mine : styles.theirs} ${r.at === selected ? styles.isSelected : ""}`}
                    aria-current={r.at === selected}
                    onClick={() => onSelect(r.at)}
                  >
                    <span className={styles.moveText}>{r.text}</span>
                    {r.decision?.label && <ReviewBadge label={r.decision.label} size="sm" />}
                  </button>
                </li>
              ) : (
                <li key={r.at} className={styles.moveNote}>
                  {r.text}
                </li>
              ),
            )}
          </ol>
        </section>
      ))}
    </div>
  );
}
