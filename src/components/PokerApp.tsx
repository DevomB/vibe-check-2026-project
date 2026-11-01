"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ActionBar } from "./ActionBar";
import { PracticeBar } from "./ChallengePicker";
import { GameOver } from "./GameOver";
import { Lobby } from "./Lobby";
import { MysteryGuess } from "./MysteryGuess";
import { ReviewModal } from "./ReviewModal";
import { RulesModal } from "./RulesModal";
import { ProofsDrawer } from "./ProofsDrawer";
import { NextHandBar } from "./ResultBanner";
import { Table, resultDelay } from "./Table";
import { type PracticeVerdict, practiceVerdict } from "@/lib/challenges";
import { chips, describeStartingHand } from "@/lib/format";
import { dropControlFocus, isTableShortcut } from "@/lib/keys";
import { type Game, type GameMode, type GameSettings, HUMAN_SEAT, TABLE, gameStatus, useGame } from "@/hooks/useGame";
import styles from "./modes.module.css";

/**
 * Job 4's two optional ReviewModal props (the contract in its task file). They travel in a
 * spread: before job 4's ReviewModal declares them, TypeScript accepts them and the modal
 * ignores them; once it declares them, TypeScript checks them against these types.
 */
interface ReviewModalExtras {
  /** True while a Mystery game is not yet revealed. */
  hideSliderInfo?: boolean;
  /** Open the Proofs drawer at that guarantee ("review", "bluff" or "risk"). */
  onShowProof?: (id: string) => void;
}

/** A Mystery bot may be guessed after this many finished hands, or at game over. The route enforces it. */
const REVEAL_AFTER_HANDS = 3;

/** Hands already finished: those before the current one, and the current one once it is over. */
function finishedHands(game: Game): number {
  return game.lean.status === "playing" ? game.lean.hand - 1 : game.lean.hand;
}

export function PokerApp() {
  const { game, error, thinking, review, loading, peek, peekedHands, setPeek, start, startChallenge, humanAct, nextHand, openReview, closeReview, reveal, quit } =
    useGame();
  const [showRules, setShowRules] = useState(false);
  /** The "What is guaranteed?" drawer: closed (null), or open at a guarantee id (or the top). */
  const [proofs, setProofs] = useState<{ focus: string | null } | null>(null);
  const closeProofs = useCallback(() => setProofs(null), []);
  // The sliders used last, so the setup screen keeps them after leaving a table.
  const [lastSettings, setLastSettings] = useState<GameSettings | undefined>(undefined);
  const status = game ? gameStatus(game) : null;
  const lost = game?.lost ?? null;
  const mode = game?.mode;

  // Lean takes about half a second to grade a hand. Meanwhile the Review button says "Opening…".
  const [reviewOpening, setReviewOpening] = useState(false);
  const openReviewNow = useCallback(async () => {
    setReviewOpening(true);
    try {
      await openReview();
    } finally {
      setReviewOpening(false);
    }
  }, [openReview]);

  // From Start until Lean's first reply, the setup screen gives way to "Dealing…". The first start
  // on a laptop can take seconds, while Windows scans the newly built engine.
  const [starting, setStarting] = useState(false);
  useEffect(() => {
    if (game) setStarting(false);
  }, [game]);

  // Practice: once the rehearsed hand is over, open Lean's review on its own, after the result
  // has had time to show. Only once per loaded challenge.
  const practiceOver = mode?.kind === "practice" && game?.lean.hand === 1 && game.lean.result !== null && lost === null;
  const practiceDelayMs = game && practiceOver ? (resultDelay(game) + 1.2) * 1000 : 0;
  const autoReviewed = useRef<GameMode | null>(null);
  useEffect(() => {
    if (!practiceOver || !mode || autoReviewed.current === mode) return;
    const timer = window.setTimeout(() => {
      autoReviewed.current = mode;
      void openReviewNow();
    }, practiceDelayMs);
    return () => window.clearTimeout(timer);
  }, [practiceOver, mode, practiceDelayMs, openReviewNow]);

  // Mystery: the guess panel, and a note when a review must wait for the guess.
  const mysteryHidden = mode?.kind === "mystery" && mode.reveal === null;
  const finished = game ? finishedHands(game) : 0;
  const mayGuess = finished >= REVEAL_AFTER_HANDS || status === "gameOver";
  const [guessOpen, setGuessOpen] = useState(false);
  const [guessSending, setGuessSending] = useState(false);
  const [guessError, setGuessError] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ hand: number; text: string } | null>(null);
  const openGuess = useCallback(() => {
    setGuessError(null);
    setGuessOpen(true);
  }, []);
  // A new game (a new settings object) starts with the panel closed; a reveal keeps the same game.
  const gameSettings = game?.settings;
  useEffect(() => {
    setGuessOpen(false);
    setNotice(null);
  }, [gameSettings]);
  const submitGuess = async (risk: number) => {
    setGuessSending(true);
    setGuessError(await reveal(risk));
    setGuessSending(false);
  };
  /** Review, unless the review must wait for the Mystery guess: then guess, or say when you may. */
  const askReview = useCallback(() => {
    if (!mysteryHidden) return void openReviewNow();
    if (mayGuess) return openGuess();
    setNotice({
      hand: game?.lean.hand ?? 0,
      text: `Reviews open after you guess the bot. You can guess after ${REVEAL_AFTER_HANDS} finished hands (${finished} so far).`,
    });
  }, [mysteryHidden, mayGuess, finished, game?.lean.hand, openReviewNow, openGuess]);

  // Mystery: open the guess panel on its own once, when the third hand is over, and again at
  // game over, if the bot is still hidden.
  const guessDue = mysteryHidden && lost === null ? (status === "gameOver" ? "over" : status === "handOver" && finished >= REVEAL_AFTER_HANDS ? "third" : null) : null;
  const guessDelayMs = game && guessDue ? (resultDelay(game) + 1.6) * 1000 : 0;
  const guessPrompted = useRef<{ mode: GameMode | null; third: boolean; over: boolean }>({ mode: null, third: false, over: false });
  useEffect(() => {
    if (!guessDue || !mode) return;
    if (guessPrompted.current.mode !== mode) guessPrompted.current = { mode, third: false, over: false };
    if (guessPrompted.current[guessDue]) return;
    const timer = window.setTimeout(() => {
      guessPrompted.current = { mode, third: true, over: guessPrompted.current.over || guessDue === "over" };
      openGuess();
    }, guessDelayMs);
    return () => window.clearTimeout(timer);
  }, [guessDue, mode, guessDelayMs, openGuess]);

  // Practice: Lean's grade of the rehearsed hand, kept after the review is closed.
  const [practice, setPractice] = useState<{ mode: GameMode; verdict: PracticeVerdict } | null>(null);
  useEffect(() => {
    if (!game || game.mode.kind !== "practice" || !review || review.hand !== 1 || game.lean.hand !== 1) return;
    setPractice({ mode: game.mode, verdict: practiceVerdict(review, game.lean.result) });
  }, [game, review]);

  // The result, with its Next hand and Review buttons, shows only once an all-in run-out has been
  // dealt (`resultDelay`); CSS keeps the buttons hidden until then. The keys wait just as long,
  // so Space cannot skip the run-out.
  const result = game?.dealt.hand.result ?? null;
  const resultWaitMs = game && result ? resultDelay(game) * 1000 : 0;
  const [shownResult, setShownResult] = useState<typeof result>(null);
  useEffect(() => {
    if (!result) return;
    const timer = window.setTimeout(() => setShownResult(result), resultWaitMs);
    return () => window.clearTimeout(timer);
  }, [result, resultWaitMs]);
  const resultShown = result !== null && shownResult === result;

  useEffect(() => {
    if (status !== "handOver" || !resultShown || showRules || proofs || guessOpen || review || lost !== null) return;
    const onKey = (e: KeyboardEvent) => {
      if (!isTableShortcut(e)) return;
      // Enter on a focused button presses that button, as usual. Space and R are always the table's keys.
      const enterOnButton = e.key === "Enter" && e.target instanceof HTMLElement && e.target.closest("button, a[href]") !== null;
      if (e.key === " " || (e.key === "Enter" && !enterOnButton)) {
        e.preventDefault();
        dropControlFocus();
        nextHand();
      } else if (e.key === "r" || e.key === "R") {
        e.preventDefault();
        dropControlFocus();
        askReview();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [status, resultShown, showRules, proofs, guessOpen, review, lost, nextHand, askReview]);

  // A closed dialog leaves focus on the button that opened it (Review, for example). Drop it, so
  // the next Space or Enter goes to the table instead of opening the dialog again.
  const dialogOpen = review !== null || showRules || proofs !== null || guessOpen;
  const dialogWasOpen = useRef(false);
  useEffect(() => {
    if (dialogWasOpen.current && !dialogOpen) dropControlFocus();
    dialogWasOpen.current = dialogOpen;
  }, [dialogOpen]);

  const begin = (settings: GameSettings) => {
    setLastSettings(settings);
    setStarting(true);
    start(settings);
  };

  const rulesModal = showRules && (
    <RulesModal onClose={() => setShowRules(false)} smallBlind={TABLE.smallBlind} bigBlind={TABLE.bigBlind} />
  );

  const errorBanner = error && (
    <div className="engine-error" role="alert">
      {error}
    </div>
  );

  if (!game) {
    // A practice hand is replayed up to its river decision (several Lean commands), and a new game
    // waits for Lean's first reply. Meanwhile "Dealing…" replaces the setup screen, so "Try again"
    // does not flash the setup screen and Start cannot be clicked twice. An error shows the setup
    // screen again, with the error.
    const dealing = loading ? `Dealing "${loading.title}"…` : starting && !error ? "Dealing…" : null;
    if (dealing) {
      return (
        <div className="app app-lobby">
          <p className="dealing" role="status">
            {dealing}
          </p>
          {rulesModal}
        </div>
      );
    }
    return (
      <div className="app app-lobby">
        <Lobby initial={lastSettings} onStart={begin} onPractice={(c, fast) => void startChallenge(c, fast)} onRules={() => setShowRules(true)} />
        {errorBanner}
        {rulesModal}
      </div>
    );
  }

  const { hand, seatOf } = game.dealt;
  const replaySeed = game.seed;
  const youIndex = seatOf.indexOf(HUMAN_SEAT);
  const you = youIndex >= 0 ? hand.players[youIndex]! : null;
  // While the bot "thinks", the previous state stays on screen and the human cannot act.
  const yourTurn = !thinking && hand.toAct !== null && hand.toAct === youIndex;
  const actor = thinking ? game.players[1 - HUMAN_SEAT]! : hand.toAct !== null ? game.players[seatOf[hand.toAct]!]! : null;

  const challenge = game.mode.kind === "practice" ? game.mode.challenge : null;
  const mystery = game.mode.kind === "mystery" ? game.mode : null;
  // The bot's settings as Lean sent them. An unrevealed Mystery game has none: the route removes them.
  const shownSliders = game.lean.sliders ?? null;
  const reviewExtras: ReviewModalExtras = { hideSliderInfo: mysteryHidden, onShowProof: (id) => setProofs({ focus: id }) };

  let strength = "";
  if (you) {
    strength = game.lean.players[HUMAN_SEAT]!.handName ?? describeStartingHand(you.hole);
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">FoldProof</div>
        <div className="topbar-info">
          <span>
            Hand <b>#{game.session.handNumber}</b>
          </span>
          <span>
            Blinds <b>{TABLE.smallBlind}/{TABLE.bigBlind}</b>
          </span>
          <span>
            Your chips <b>{chips(you?.stack ?? game.session.seats[HUMAN_SEAT]!.stack)}</b>
          </span>
          {challenge && (
            <span>
              Practice <b>{challenge.title}</b>
            </span>
          )}
          <span title="The bot's Risk, and the bluff share Lean set from it">
            Bot{" "}
            <b>
              {mystery && "Mystery, "}
              {shownSliders ? `Risk ${shownSliders.risk}, bluff share ${shownSliders.bluffPct}%` : "hidden until you guess"}
            </b>
          </span>
          {replaySeed !== null && (
            <span title="Enter this seed in the lobby to replay the same cards">
              {status === "gameOver" ? "Seed" : "Replay seed"} <b>{replaySeed.toString()}</b>
            </span>
          )}
        </div>
        <div className="topbar-actions">
          <label
            className="peek-toggle"
            title="Show the bot's two cards during the hand. The review still grades your moves as if you could not see them."
          >
            <input type="checkbox" checked={peek} disabled={lost !== null} onChange={(e) => setPeek(e.target.checked)} />
            Peek at bot's cards
          </label>
          {mysteryHidden && (
            <button
              className="btn btn-primary btn-sm"
              onClick={openGuess}
              disabled={!mayGuess || lost !== null}
              title={mayGuess ? "Guess the bot's Risk" : `You can guess after ${REVEAL_AFTER_HANDS} finished hands`}
            >
              Guess the bot{mayGuess ? "" : ` (${finished}/${REVEAL_AFTER_HANDS})`}
            </button>
          )}
          {mystery?.reveal && (
            <button className="btn btn-ghost btn-sm" onClick={openGuess}>
              Your guess
            </button>
          )}
          <button className="btn btn-ghost btn-sm" onClick={() => setProofs({ focus: null })}>
            What is guaranteed?
          </button>
          <button className="btn btn-ghost btn-sm" onClick={() => setShowRules(true)}>
            How to play
          </button>
          <button className="btn btn-ghost btn-sm" onClick={quit}>
            Leave table
          </button>
        </div>
      </header>

      <main className="layout">
        <div className="play-column">
          <Table game={game} botThinking={thinking} />
          {lost !== null ? (
            <ActionBar hand={hand} legal={null} waiting="Game lost" handStrength={strength} onAct={humanAct} />
          ) : hand.result ? (
            <NextHandBar
              game={game}
              delay={resultDelay(game)}
              gameOver={status === "gameOver"}
              reviewOpening={reviewOpening}
              onNextHand={nextHand}
              onReview={askReview}
            />
          ) : (
            <ActionBar
              hand={hand}
              legal={yourTurn && !showRules && !proofs && !guessOpen ? game.legal : null}
              waiting={you?.folded ? "You folded — watching the rest" : yourTurn ? "Your turn" : actor ? `${actor.name} is thinking…` : ""}
              botMessage={thinking ? null : game.botLine}
              handStrength={strength}
              onAct={humanAct}
            />
          )}
          {challenge && lost === null && (
            <PracticeBar
              game={game}
              challenge={challenge}
              verdict={practice?.mode === game.mode ? practice.verdict : null}
              overReview={review !== null}
              onRetry={() => void startChallenge(challenge, game.settings.fast)}
            />
          )}
          {notice && notice.hand === game.lean.hand && mysteryHidden && (
            <p className={styles.loading} role="status">
              {notice.text}
            </p>
          )}
          {errorBanner}
        </div>
      </main>

      {lost !== null && (
        <div className="modal-backdrop">
          <div className="modal game-over" role="alertdialog" aria-label="Game lost">
            <div className="game-over-icon">⚠</div>
            <h2>This game was lost</h2>
            <p className="muted">{lost}</p>
            <div className="modal-actions">
              <button className="btn btn-primary" onClick={quit}>
                New game
              </button>
            </div>
          </div>
        </div>
      )}
      {lost === null && status === "gameOver" && (replaySeed !== null || mysteryHidden) && (
        <GameOver
          delay={resultDelay(game) + 1.2}
          won={game.session.seats[HUMAN_SEAT]!.stack > 0}
          stats={game.stats}
          seed={mysteryHidden ? null : replaySeed}
          replay={{
            sliders: game.lean.sliders ?? null,
            turnMode: game.lean.turnMode,
            engineCommit: game.lean.engineCommit,
            serverCommit: game.lean.serverCommit ?? "unknown",
          }}
          // A Mystery game's "New game" deals a new Mystery bot.
          onAgain={() => start({ ...game.settings, seed: null })}
          // A replay is a normal game with the same seed and Risk (a revealed Mystery bot's real one).
          onReplay={() => start({ ...game.settings, risk: game.lean.sliders?.risk ?? game.settings.risk, mystery: false, seed: replaySeed })}
          onReview={askReview}
          onLobby={quit}
          onGuess={mysteryHidden ? openGuess : undefined}
        />
      )}
      {guessOpen && mystery && (
        <MysteryGuess
          reveal={mystery.reveal}
          sliders={mystery.reveal ? (game.lean.sliders ?? null) : null}
          sending={guessSending}
          error={guessError}
          onGuess={(risk) => void submitGuess(risk)}
          onClose={() => setGuessOpen(false)}
          onReview={
            status !== "playing"
              ? () => {
                  setGuessOpen(false);
                  void openReviewNow();
                }
              : undefined
          }
        />
      )}
      {review && (
        <ReviewModal
          key={review.hand}
          {...reviewExtras}
          review={review}
          game={game}
          peeked={peekedHands.includes(review.hand)}
          onClose={closeReview}
        />
      )}
      {proofs && <ProofsDrawer focus={proofs.focus} onClose={closeProofs} />}
      {rulesModal}
    </div>
  );
}
