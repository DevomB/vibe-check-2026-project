"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import type { KuhnCard, KuhnCommand, KuhnMove, KuhnReply, KuhnState } from "@/lean/kuhn";
import type { Card } from "@/lib/cards";
import { PlayingCard } from "./PlayingCard";
import styles from "./kuhn.module.css";

/**
 * Kuhn poker against the bot that plays a proven Nash equilibrium. Every rule decision (the
 * deal, which moves are allowed, the bot's moves, who wins) is made in Lean (engine/KuhnServe.lean)
 * and arrives through /api/kuhn; this page only draws the table and sends your clicks.
 */

/** Kuhn poker's three cards, drawn with fixed suits. */
const CARD: Record<KuhnCard, Card> = { jack: "Js", queen: "Qh", king: "Kc" };
const CARD_NAME: Record<KuhnCard, string> = { jack: "Jack", queen: "Queen", king: "King" };
const MOVE_LABEL: Record<KuhnMove, string> = { check: "Check", bet: "Bet 1", call: "Call 1", fold: "Fold" };

/** What is proved, in plain words, with the Lean theorem behind each line. */
const PROOFS: { says: string; theorem: string }[] = [
  { says: "The bot's strategy is a Nash equilibrium of Kuhn poker: with fair random numbers for the deals and its rolls, no way of playing beats it on average.", theorem: "kuhn_nash, kuhn_game_unbeatable" },
  { says: "This game gives exactly the results the theory predicts, for every way you can play.", theorem: "botP1Total_eq, botP2Total_eq" },
  { says: "The bot rolls the right odds: it bluffs a jack exactly one time in three.", theorem: "botP1_frequencies, botP2_frequencies" },
  { says: "Every deal is equally likely, and only moves allowed by the rules are accepted.", theorem: "kDeal_each_once, kuhn_game_follows_rules" },
];

async function send(command: KuhnCommand): Promise<KuhnReply> {
  const response = await fetch("/api/kuhn", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(command),
  });
  return (await response.json()) as KuhnReply;
}

function chipsText(n: number): string {
  const sign = n > 0 ? "+" : n < 0 ? "−" : "";
  return `${sign}${Math.abs(n)} chip${Math.abs(n) === 1 ? "" : "s"}`;
}

export function KuhnApp() {
  const [state, setState] = useState<KuhnState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const busy = useRef(false);

  const run = useCallback(async (command: KuhnCommand) => {
    if (busy.current) return;
    busy.current = true;
    try {
      const reply = await send(command);
      if ("ok" in reply) {
        setError(null);
        setState(reply.state);
      } else {
        setError(reply.error);
        if (reply.state) setState(reply.state);
      }
    } catch (e) {
      setError(`Could not reach the game engine: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      busy.current = false;
    }
  }, []);

  // Pick up where the server's game is (a reload keeps the score).
  useEffect(() => {
    void run({ cmd: "state" });
  }, [run]);

  const hand = state?.hand ?? null;
  const canDeal = !hand || hand.over;

  // Keyboard: Space or Enter deals; C, B and F make a move.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat || (e.target instanceof HTMLElement && e.target.closest("button, a, input"))) return;
      const key = e.key.toLowerCase();
      if ((key === " " || key === "enter") && canDeal) {
        e.preventDefault();
        void run({ cmd: "new_hand" });
        return;
      }
      const legal = hand?.legal ?? [];
      const pick = legal.find((m) => (key === "c" && (m === "check" || m === "call")) || (key === "b" && m === "bet") || (key === "f" && m === "fold"));
      if (pick) {
        e.preventDefault();
        void run({ cmd: "move", move: pick });
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [hand, canDeal, run]);

  // Chips in the middle: two antes, plus one for every bet or call.
  const pot = hand ? 2 + hand.moves.filter((m) => m.move === "bet" || m.move === "call").length : 0;
  const average = state && state.hands > 0 ? state.total / state.hands : null;

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">FoldProof</div>
        <div className="topbar-info">
          <span>Kuhn poker</span>
          <span>
            Hands <b>{state?.hands ?? 0}</b>
          </span>
          <span>
            Your total <b>{chipsText(state?.total ?? 0)}</b>
          </span>
        </div>
        <div className="topbar-actions">
          <button className="btn btn-ghost btn-sm" onClick={() => void run({ cmd: "reset" })} disabled={!state || (state.hands === 0 && !state.hand)}>
            Start over
          </button>
          <Link className="btn btn-ghost btn-sm" href="/">
            Hold&apos;em
          </Link>
        </div>
      </header>

      <main className={styles.layout}>
        <section className={styles.table} aria-label="Kuhn poker table">
          <div className={styles.seat}>
            <div className={styles.seatName}>
              Bot <span className={styles.seatRole}>{hand ? `player ${hand.yourSeat === 1 ? 2 : 1}` : ""}</span>
            </div>
            {hand ? (
              <PlayingCard card={hand.botCard ? CARD[hand.botCard] : null} faceDown={!hand.botCard} size="lg" />
            ) : (
              <div className={styles.cardSpace} />
            )}
          </div>

          <div className={styles.middle}>
            {hand ? (
              <>
                <div className={styles.pot}>Pot {pot}</div>
                <ol className={styles.moves} aria-label="Moves this hand">
                  {hand.moves.map((m, i) => (
                    <li key={i} className={m.by === "you" ? styles.moveYou : styles.moveBot}>
                      {m.by === "you" ? "You" : "Bot"}: {m.move}
                    </li>
                  ))}
                </ol>
                {hand.over && hand.result !== null && (
                  <div className={`${styles.result} ${hand.result > 0 ? styles.win : hand.result < 0 ? styles.lose : ""}`} role="status">
                    {hand.result > 0 ? "You win" : "You lose"} {Math.abs(hand.result)}
                    <span className={styles.resultWhy}>
                      {hand.showdown && hand.botCard
                        ? `Showdown: your ${CARD_NAME[hand.yourCard]} against the bot's ${CARD_NAME[hand.botCard]}`
                        : hand.moves.at(-1)?.by === "you"
                          ? "You folded"
                          : "The bot folded"}
                    </span>
                  </div>
                )}
              </>
            ) : (
              <p className={styles.intro}>
                Three cards: Jack, Queen, King. Each player puts in 1 chip and gets one card. One bet of 1 chip is allowed; the higher card wins a
                showdown.
              </p>
            )}
          </div>

          <div className={styles.seat}>
            {hand ? <PlayingCard card={CARD[hand.yourCard]} size="lg" /> : <div className={styles.cardSpace} />}
            <div className={styles.seatName}>
              You <span className={styles.seatRole}>{hand ? `player ${hand.yourSeat}${hand.yourSeat === 1 ? ", act first" : ""}` : ""}</span>
            </div>
          </div>
        </section>

        <div className={styles.actions}>
          {canDeal ? (
            <button className="btn btn-primary btn-big" onClick={() => void run({ cmd: "new_hand" })}>
              {hand ? "Next hand" : "Deal"} <kbd>Space</kbd>
            </button>
          ) : hand && hand.toAct === "you" ? (
            hand.legal.map((m) => (
              <button key={m} className={`btn ${m === "fold" ? "btn-fold" : m === "bet" ? "btn-raise" : "btn-call"}`} onClick={() => void run({ cmd: "move", move: m })}>
                {MOVE_LABEL[m]} <kbd>{m === "fold" ? "F" : m === "bet" ? "B" : "C"}</kbd>
              </button>
            ))
          ) : (
            <span className={styles.waiting}>The bot is thinking…</span>
          )}
        </div>

        {error && (
          <div className="engine-error" role="alert">
            {error}
          </div>
        )}

        <section className={styles.panels}>
          <div className={styles.panel}>
            <h2 className={styles.panelTitle}>Can you beat it?</h2>
            <p className={styles.big}>{average === null ? "—" : `${average >= 0 ? "+" : "−"}${Math.abs(average).toFixed(3)}`}</p>
            <p className={styles.muted}>Your average per hand, in chips, over {state?.hands ?? 0} hands.</p>
            <p className={styles.muted}>
              Proved: playing both seats in turn, nobody wins chips on average. As player 1 the best you can do is −1/18 (−0.056) a hand; as player 2,
              +1/18. Luck evens out over many hands.
            </p>
          </div>
          <div className={styles.panel}>
            <h2 className={styles.panelTitle}>What Lean proves</h2>
            <ul className={styles.proofs}>
              {PROOFS.map((p) => (
                <li key={p.theorem}>
                  {p.says}
                  <code className={styles.theorem}>{p.theorem}</code>
                </li>
              ))}
            </ul>
          </div>
        </section>
      </main>
    </div>
  );
}
