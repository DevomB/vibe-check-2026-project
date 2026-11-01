import { useEffect } from "react";
import type { Card } from "@/lib/cards";
import { PlayingCard } from "./PlayingCard";

const RANKINGS: { name: string; about: string; cards: Card[] }[] = [
  { name: "Royal Flush", about: "A, K, Q, J, 10, all the same suit.", cards: ["As", "Ks", "Qs", "Js", "Ts"] },
  { name: "Straight Flush", about: "Five cards in a row, all the same suit.", cards: ["9h", "8h", "7h", "6h", "5h"] },
  { name: "Four of a Kind", about: "Four cards of the same rank.", cards: ["Qc", "Qd", "Qh", "Qs", "4d"] },
  { name: "Full House", about: "Three of a kind plus a pair.", cards: ["Kd", "Kh", "Ks", "5c", "5d"] },
  { name: "Flush", about: "Any five cards of the same suit.", cards: ["Ad", "Jd", "8d", "6d", "2d"] },
  { name: "Straight", about: "Five cards in a row, any suits. A-2-3-4-5 counts.", cards: ["Tc", "9d", "8s", "7h", "6c"] },
  { name: "Three of a Kind", about: "Three cards of the same rank.", cards: ["7c", "7d", "7s", "Kh", "2c"] },
  { name: "Two Pair", about: "Two different pairs.", cards: ["Jh", "Js", "4c", "4d", "As"] },
  { name: "Pair", about: "Two cards of the same rank.", cards: ["Ah", "Ad", "Kc", "8s", "3d"] },
  { name: "High Card", about: "None of the above: the highest card plays.", cards: ["Ac", "Qd", "9h", "6s", "3c"] },
];

export function RulesModal({ onClose, smallBlind, bigBlind }: { onClose: () => void; smallBlind: number; bigBlind: number }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal rules" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="How to play">
        <button className="modal-close" onClick={onClose} aria-label="Close">
          ×
        </button>
        <h2>How to play Texas Hold'em</h2>

        <div className="rules-grid">
          <section>
            <h3>The goal</h3>
            <p>Win chips. You win a pot by having the best five-card hand at the end, or by making everyone else fold.</p>

            <h3>A hand, step by step</h3>
            <ol>
              <li>
                <b>Blinds.</b> The two players left of the dealer button put in forced bets: the small blind ({smallBlind}) and the big
                blind ({bigBlind}). With two players, the button posts the small blind.
              </li>
              <li>
                <b>Pre-flop.</b> Everyone gets two private cards. Betting starts left of the big blind.
              </li>
              <li>
                <b>Flop.</b> Three shared cards are dealt face up. Another betting round, starting left of the button.
              </li>
              <li>
                <b>Turn.</b> A fourth shared card, then a betting round.
              </li>
              <li>
                <b>River.</b> A fifth shared card, then the last betting round.
              </li>
              <li>
                <b>Showdown.</b> Players still in show their cards. Each makes the best five-card hand from their two cards and the five
                shared cards. The best hand wins the pot.
              </li>
            </ol>
            <p className="muted">The button moves one seat to the left after each hand.</p>
          </section>

          <section>
            <h3>On your turn</h3>
            <ul>
              <li>
                <b>Fold</b>: give up the hand.
              </li>
              <li>
                <b>Check</b>: pass, if nobody has bet this round.
              </li>
              <li>
                <b>Call</b>: match the current bet.
              </li>
              <li>
                <b>Bet / Raise</b>: put in more. This is no-limit: you can bet any amount up to all your chips. A raise must be at least
                as big as the last full bet or raise, unless you are all-in.
              </li>
              <li>
                <b>All-in</b>: bet all your chips. If you can't match a bet, you can still call all-in for what you have.
              </li>
            </ul>

            <h3>Pots</h3>
            <p>
              With two players, any unmatched part of a bet is returned. Only matched chips can be won. Equal hands split the pot.
            </p>
            <p className="muted">Shortcuts: F fold · C check/call · R bet/raise · Space next hand</p>
          </section>
        </div>

        <h3>Hand rankings, best to worst</h3>
        <div className="rankings">
          {RANKINGS.map((r, i) => (
            <div key={r.name} className="ranking">
              <span className="ranking-num">{i + 1}</span>
              <div className="ranking-text">
                <b>{r.name}</b>
                <span>{r.about}</span>
              </div>
              <div className="ranking-cards">
                {r.cards.map((c) => (
                  <PlayingCard key={c} card={c} size="sm" />
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
