import { useEffect, useRef, useState } from "react";
import type { LeanReview } from "@/lean/protocol";
import type { Card } from "@/lib/cards";
import type { GuaranteeId } from "@/lib/guarantees";
import { type Game, HUMAN_SEAT, describeEvents } from "@/hooks/useGame";
import {
  type MoveRow,
  type Street,
  boardAt,
  buildMoveList,
  gradedCoach,
  labelCounts,
  movesFromReview,
  noGradeReason,
  selectableMoves,
  streetAt,
} from "@/lib/review";
import { CardSlot, PlayingCard } from "./PlayingCard";
import { EquityBar } from "./EquityBar";
import { MoveList } from "./MoveList";
import { RangeViewer } from "./RangeViewer";
import { ReviewBadge } from "./ReviewBadge";
import { RiskExplorer, firstInteresting } from "./RiskExplorer";
import { WhyChip } from "./WhyChip";
import styles from "./review.module.css";

interface Props {
  review: LeanReview;
  /**
   * The game the reviewed hand belongs to. Its events give the move list and its cards the
   * picture of each moment; without it, the list shows only your moves.
   */
  game?: Game | null;
  /** "Peek at bot's cards" was on while this hand was played. Display only. */
  peeked?: boolean;
  /**
   * Hide what would give away the bot's settings: the range viewer, the Risk explorer and the
   * bot's detailed reasons. Mystery mode sets it until the reveal.
   */
  hideSliderInfo?: boolean;
  /**
   * When given, the proof links call it with a guarantee id: "review" for the grades and the
   * range viewer's counts, "hindsight" for "the grade ignores the bot's cards", "risk" for the
   * Risk explorer.
   */
  onShowProof?: (id: GuaranteeId) => void;
  onClose: () => void;
}

const STREET_NAME: Record<Street, string> = { preflop: "Preflop", flop: "Flop", turn: "Turn", river: "River" };

const NOT_GRADED = "Not graded: Lean grades only your call or fold when the bot bets first on the river.";

function Cards({ cards, slots = 0 }: { cards: readonly Card[]; slots?: number }) {
  return (
    <div className={styles.cards}>
      {cards.map((c) => (
        <PlayingCard key={c} card={c} size="sm" />
      ))}
      {Array.from({ length: Math.max(0, slots - cards.length) }, (_, i) => (
        <CardSlot key={`slot-${i}`} size="sm" />
      ))}
    </div>
  );
}

function Chevron({ dir, bar = false }: { dir: "left" | "right"; bar?: boolean }) {
  const flip = dir === "left" ? "scale(-1 1) translate(-16 0)" : undefined;
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
      <g transform={flip}>
        <path d={bar ? "M3.5 3l5 5-5 5" : "M5 3l5 5-5 5"} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        {bar && <path d="M12.5 3v10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
      </g>
    </svg>
  );
}

/**
 * After a hand: Lean's review, laid out like a chess move review. A move list with a badge on
 * each graded move, a coach line for the selected move, a bar with your chances against the
 * chances a call needed, the range viewer, the Risk explorer and the bot's reasons. Every
 * number comes from Lean; this screen only arranges and words them.
 */
export function ReviewModal({ review, game = null, peeked = false, hideSliderInfo = false, onShowProof, onClose }: Props) {
  const human = HUMAN_SEAT;
  const sameHand = game !== null && game.lean.hand === review.hand;
  const names = game?.players.map((p) => p.name) ?? ["You", "The bot"];
  const botName = names[1 - human] ?? "The bot";
  const events = sameHand ? game.handEvents : null;
  const fromEvents = events ? buildMoveList(events, describeEvents(events, names, 0), review, human) : null;
  const streets = fromEvents ?? movesFromReview(review, human);
  const moves = selectableMoves(streets);
  const gradedRow = moves.find((r) => r.decision?.label != null) ?? null;
  const gradedCount = review.decisions.filter((d) => d.label !== null).length;
  const range = review.decisions.find((d) => d.label !== null && d.range)?.range ?? null;

  // The selected move, by its place in the hand's events; null is the start, before any move.
  const [selected, setSelected] = useState<number | null>(() => gradedRow?.at ?? null);
  const index = selected === null ? -1 : moves.findIndex((r) => r.at === selected);
  const row: MoveRow | null = index >= 0 ? moves[index]! : null;

  const explorer = hideSliderInfo ? null : (review.risk_explorer ?? null);
  // The Risk explorer shows the bot move selected last; picking a move there selects it in the list.
  const [explorerIndex, setExplorerIndex] = useState(() => (explorer ? firstInteresting(explorer) : 0));
  const select = (at: number | null) => {
    setSelected(at);
    const botMove = moves.find((m) => m.at === at)?.botMove;
    if (botMove !== undefined && botMove !== null) setExplorerIndex(botMove);
  };
  const pickInExplorer = (i: number) => {
    setExplorerIndex(i);
    const r = moves.find((m) => m.botMove === i);
    if (r) setSelected(r.at);
  };

  const step = (to: "start" | "back" | "next" | "end") => {
    const target = to === "start" ? -1 : to === "end" ? moves.length - 1 : to === "back" ? index - 1 : Math.min(index + 1, moves.length - 1);
    select(target >= 0 ? (moves[target]?.at ?? null) : null);
  };
  const stepRef = useRef(step);
  stepRef.current = step;
  const dialogRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const keys: Record<string, "start" | "back" | "next" | "end"> = { ArrowLeft: "back", ArrowRight: "next", Home: "start", End: "end" };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") return onClose();
      const to = keys[e.key];
      if (!to || (e.target instanceof HTMLElement && e.target.closest("input, textarea, select, [contenteditable]"))) return;
      // Only while the review is the top dialog: not under the Proofs drawer.
      const dialogs = document.querySelectorAll('[role="dialog"]');
      if (dialogs[dialogs.length - 1] !== dialogRef.current) return;
      e.preventDefault();
      stepRef.current(to);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  // The picture of the selected moment: the board then, your cards, and the bot's cards if a showdown showed them.
  const at = row?.at ?? null;
  const board = fromEvents ? boardAt(streets, at) : sameHand ? game.lean.board : [];
  const street = fromEvents ? streetAt(streets, at) : (row?.decision?.street ?? null);
  const yourCards = sameHand ? (game.lean.players[human]?.cards ?? []) : [];
  const shownBotCards = sameHand && game.lean.result?.showdown ? (game.lean.players[1 - human]?.cards ?? null) : null;
  // Mystery: hands finished before the guess were decided without knowing the bot's Risk.
  const decidedBeforeReveal = game?.mode.kind === "mystery" && game.mode.reveal !== null && review.hand <= (game.mode.handsBeforeReveal ?? 0);

  const coach = row?.decision ? gradedCoach(row.decision) : null;
  const reasons = hideSliderInfo ? null : review.bot_reasons;
  const botReason = row && row.botMove !== null && reasons ? (reasons[row.botMove] ?? null) : null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        ref={dialogRef}
        className={`modal ${styles.modal} ${game?.mode.kind === "practice" ? styles.roomForBar : ""}`}
        role="dialog"
        aria-label={`Review of hand ${review.hand}`}
        onClick={(e) => e.stopPropagation()}
      >
        <button className="modal-close" onClick={onClose} aria-label="Close">
          ×
        </button>

        <header className={styles.header}>
          <h2>Hand #{review.hand} review</h2>
          <ul className={styles.summary} aria-label="Grades in this hand">
            {labelCounts(review.decisions).map(({ info, count }) => (
              <li key={info.key} className={count === 0 ? styles.isZero : ""}>
                <ReviewBadge label={info.label} size="sm" />
                <span>{info.label}</span>
                <b>{count}</b>
              </li>
            ))}
          </ul>
        </header>

        {peeked && (
          <p className={styles.note} role="note">
            You peeked at the bot&apos;s cards this hand. The grade assumes you didn&apos;t know them.
          </p>
        )}

        <div className={styles.main}>
          <div className={styles.side}>
            <EquityBar had={coach ? (row?.decision?.equity_had ?? null) : null} needed={coach ? (row?.decision?.equity_needed ?? null) : null} />
            {sameHand && (
              <div className={styles.spot}>
                <div className={styles.spotStreet}>{street ? STREET_NAME[street] : "The hand"}</div>
                <div className={styles.spotPart}>
                  <span>Board</span>
                  <Cards cards={board} slots={5} />
                </div>
                <div className={styles.spotPart}>
                  <span>You</span>
                  <Cards cards={yourCards} />
                </div>
                <div className={styles.spotPart}>
                  <span>{botName}</span>
                  {shownBotCards ? (
                    <Cards cards={shownBotCards} />
                  ) : (
                    <div className={styles.cards}>
                      <PlayingCard card={null} faceDown size="sm" />
                      <PlayingCard card={null} faceDown size="sm" />
                    </div>
                  )}
                </div>
                {shownBotCards && <p className={styles.spotNote}>Shown at the end. The grade does not use them.</p>}
              </div>
            )}
          </div>

          <div className={styles.panel}>
            <div className={`${styles.coach} ${coach ? styles[`tone-${row?.decision?.label?.toLowerCase()}`] : ""}`} aria-live="polite">
              {coach && row?.decision?.label ? (
                <>
                  <p className={styles.coachHead}>
                    <ReviewBadge label={row.decision.label} size="lg" />
                    <b>{coach.headline}</b>
                  </p>
                  {(coach.chances || coach.better) && (
                    <p>
                      {coach.chances} {coach.better}
                    </p>
                  )}
                  <p className={styles.coachNumbers}>
                    {coach.worths} <span className={styles.band}>{coach.band}</span>
                  </p>
                  <WhyChip ideas={["pot-odds", "grade-bands"]} />
                </>
              ) : row ? (
                <>
                  <p className={styles.coachHead}>
                    <b>{row.text}.</b>
                  </p>
                  {row.player === human ? (
                    <p className="muted">{NOT_GRADED}</p>
                  ) : botReason ? (
                    <p>
                      Its reason: <q>{botReason}</q>
                    </p>
                  ) : hideSliderInfo ? (
                    <p className="muted">The bot&apos;s reasons stay hidden until you guess its Risk.</p>
                  ) : null}
                </>
              ) : gradedCount > 0 ? (
                <p>Step through the hand with the arrows below or the ← → keys. Your graded move carries its badge.</p>
              ) : (
                <>
                  <p className={styles.coachHead}>
                    <b>No graded move in this hand.</b>
                  </p>
                  <p>{noGradeReason(events)}</p>
                  <p className="muted">Practice hands on the setup screen always reach that spot.</p>
                </>
              )}
            </div>

            {coach && (
              <div className={styles.model}>
                <p>
                  The grade counts every hand the bot bets on this river as equally likely, minus the hands your cards rule out. It ignores how
                  the bot played earlier.
                </p>
                {decidedBeforeReveal && <p>Graded with the bot&apos;s real settings, which you did not know when you decided.</p>}
              </div>
            )}

            <MoveList streets={streets} selected={selected} onSelect={select} human={human} />
            {!fromEvents && <p className={styles.moveNote}>Only your moves are listed: the hand&apos;s full record is not available.</p>}

            <div className={styles.nav}>
              <button type="button" aria-label="Start" title="Start (Home)" onClick={() => step("start")} disabled={index < 0}>
                <Chevron dir="left" bar />
              </button>
              <button type="button" aria-label="Previous move" title="Previous move (←)" onClick={() => step("back")} disabled={index < 0}>
                <Chevron dir="left" />
              </button>
              <button type="button" aria-label="Next move" title="Next move (→)" onClick={() => step("next")} disabled={index >= moves.length - 1}>
                <Chevron dir="right" />
              </button>
              <button type="button" aria-label="Last move" title="Last move (End)" onClick={() => step("end")} disabled={index >= moves.length - 1}>
                <Chevron dir="right" bar />
              </button>
            </div>

            {gradedCount > 0 && onShowProof && (
              <div className={styles.linkRow}>
                <button type="button" className={styles.proofLink} onClick={() => onShowProof("review")}>
                  Why can I trust this grade?
                </button>
                <button type="button" className={styles.proofLink} onClick={() => onShowProof("hindsight")}>
                  Does the grade use the bot&apos;s cards? No. See the proof.
                </button>
              </div>
            )}
          </div>
        </div>

        {!hideSliderInfo && range && (
          <section className={styles.section}>
            <RangeViewer range={range} onShowProof={onShowProof} />
          </section>
        )}

        {explorer && explorer.length > 0 && (
          <section className={styles.section}>
            <h3>What if the bot&apos;s Risk were different?</h3>
            <RiskExplorer entries={explorer} selected={explorerIndex} onSelect={pickInExplorer} onShowProof={onShowProof} />
          </section>
        )}

        <section className={styles.section}>
          {hideSliderInfo ? (
            <p className="muted">The bot&apos;s reasons, the hands it bets and the Risk explorer stay hidden until its Risk is revealed.</p>
          ) : (
            <>
              <h3>Why the bot played this way</h3>
              {reasons && reasons.length > 0 ? (
                <ol className={styles.reasons}>
                  {reasons.map((r, i) => (
                    <li key={i}>{r}</li>
                  ))}
                </ol>
              ) : (
                <p className="muted">The bot made no moves this hand.</p>
              )}
            </>
          )}
        </section>

        <div className="modal-actions">
          <button className="btn btn-primary" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
