Build path changed: no. `Makefile`, `package.json`, lockfiles, toolchain files, `scripts/` and `next.config.ts` are unchanged. No Lean file changed.

# Job 5 report: Proofs drawer, practice challenges, Mystery opponent (branch `modes-and-proofs`)

Worktree `C:\Coding-Projects\vc-modes`. Branched from `origin/web-hardening` at `65b16f9`, the commit where job 1's
report says "Ready for dependent jobs: yes" (polled every 60 s until then). `node_modules` is a junction to the main
checkout. Engine: job 1's binary, `C:\Coding-Projects\vc-web\engine\.lake\build\bin\poker.exe`.

## Status

| Feature | Status | Commit |
| --- | --- | --- |
| Baseline | done: typecheck clean, 230/230 tests | none |
| 1. Proofs drawer, "What is guaranteed?" | done | `ff381b9` |
| 2. Practice challenges | done | `bd45c55` |
| 3. Mystery opponent | done | `d80e5b8` |
| This report | done | the commit after `d80e5b8` |

## Checks run

- `npm run typecheck`: clean, on every commit.
- `npm test` with `POKER_BIN` set: 17 files, 284 tests, all pass. Baseline was 14 files, 230 tests. New:
  - `src/lib/guarantees.test.ts` (36): every theorem the drawer names is in `engine/comparator.json`; ids T1-T8 in
    order; every entry complete; no theorem listed twice; the review's link ids open the right entries.
  - `src/lib/challenges.test.ts` (11): each spot, replayed through the route, stops at the bot's opening river bet;
    Lean grades both call and fold with the recorded labels and worths; the Best choice ends as recorded; the
    "unlucky" line shows only for `right-and-lose`.
  - `src/app/api/game/mystery.test.ts` (7): see Mystery below.
- **The Mystery tests catch leaks.** I switched hiding off on purpose and reran them: 5 of 7 failed. The 2 that
  passed do not depend on hiding: "reveal outside Mystery" and "normal games unchanged". Then I restored the code.
- **`npm run build` passes**, including its TypeScript step. In this worktree it needs a temporary
  `turbopack.root` line in `next.config.ts`, because `node_modules` is a junction (job 1's note). The line was added
  for the build and removed after it. The committed file has no such line.
- **HTTP check** on `next start`, port 3927. It was stopped afterwards, and nothing is left listening.
  - The page has the Mystery toggle and the three practice buttons.
  - A Mystery `new_game` reply has no `sliders`, no `botReasons`, and `seed: null`.
  - A reveal at 0 finished hands gets 400 "Play 3 hands before you guess (0 finished so far)."
  - A review before the reveal gets `reviewDeferred: true` and no `review`.
  - After a normal `new_game`, a reveal gets 400 "There is no Mystery game to reveal."
- Not checked: the screens in a browser, by eye.
- Heavy commands (typecheck, tests, build) ran one at a time under the named mutex `Local\VibeCheckHeavyWork`,
  which was released in `finally` each time.

## 1. Proofs drawer (`ff381b9`)

- `src/lib/guarantees.ts` has one entry per guarantee: `chips` T1, `cards` T2, `legal` T3, `risk` T4, `review` T5,
  `equity` T6, `bluff` T7 and `hindsight` T8. Each entry has a title, plain words, its Lean names, what it assumes and
  what it does not cover. A "What we trust" list follows.
- **Source of the wording.** I took the names and meanings from the statements and docstrings in
  `engine/Checks/Challenge.lean` at `df6904a`, not from the MVP's wording.
  - `review_lost` is included: Aarav added it to Comparator on main.
  - All 32 Comparator theorems are listed, each once.
- `ProofsDrawer.tsx` slides in from the right. You open it with "What is guaranteed?" in the table's top bar, or
  through `onShowProof(id)`, which scrolls to that entry and outlines it.
  - It sits above the review modal.
  - Escape closes only the drawer, not a review under it.
  - Keyboard shortcuts and action buttons are off while it is open.
- Styles for all three features are in a new `src/components/modes.module.css`. `globals.css` is untouched, so this
  branch cannot conflict there with job 4.

## 2. Practice challenges (`bd45c55`)

- **Spots: from job 3's file, not my own finder.** They are copied from `docs/demo/challenges.json` on
  `release-docs` (`f55a3ee`, verified by job 3's replays). I wrote no `tools/find-challenges.mjs` and repeated no
  search. `challenges.test.ts` shows the spots still hold on job 1's engine.

  | Spot | Seed, Risk, Bluff | Moves before the river | Lean's labels |
  | --- | --- | --- | --- |
  | `catch-bluff` | 1, 0, 60% | call, check, check | call Best (+1.57 BB), fold Inaccuracy |
  | `avoid-bad-call` | 6, 0, 60% | raise to 30, check, check | call Mistake (-2.67 BB), fold Best |
  | `right-and-lose` | 4, 0, 60% | call, check, call | call Best (+10.32 BB) but loses 90 chips at showdown; fold Blunder |

- **Loading a spot.** Each setup-screen button does this:
  1. starts a new game with the spot's seed and sliders;
  2. sends the moves through the normal `act` command, without the bot's thinking pauses;
  3. shows the table only once Lean's reply is the decision (hand 1, river, your turn, a bet to call).

  If Lean's reply is anything else, the challenge stops with an error instead of going on from another spot.
- **The decision and the grade.**
  - A one-line prompt sits under the table at the decision.
  - When the hand ends, Lean's review opens on its own.
  - The practice line then says "Lean graded your call: Best." (or fold, or another label), read from Lean's review.
  - A Best call that loses at showdown adds: "Right decision, unlucky result. The grade looks at the decision, not
    the cards that came."
  - The recorded labels in `challenges.ts` are used only by the tests, never by the screen.
- "Try again" reloads the same spot. After hand 1 the game goes on as a normal game with the spot's sliders.

## 3. Mystery opponent (`d80e5b8`)

- **Setup.**
  - A "Mystery opponent" toggle hides the named opponents, the sliders and the seed field.
  - The route picks Risk 0-100 (`randomInt(101)`), Bluff 0-60 and a private seed, and keeps them for that game.
  - A Mystery `new_game` sent with a seed or sliders gets a 400.
- **Hidden until the reveal, in every reply, error replies included:**
  - `state.sliders` and `state.botReasons` are removed. The reasons quote the sliders ("at Risk 50").
  - `seed` stays null, even at game over. With the seed and the moves, you could replay the game at each setting
    and find the hidden ones.
  - **The whole review waits.** A `review` request gets `reviewDeferred: true` and no `review`. Its labels, worths
    and equities come from the bot's betting set at its Bluff setting, so no field of it is safe to send.
    `bot_reasons`, and job 4's `range` and `risk_explorer`, go with it.
  - The bot is "Mystery bot" for every setting, so no preset name gives the settings away.
  - The game-over screen shows "hidden until you guess" for the seed, Risk and Bluff, and offers "Guess the bot"
    instead of "Replay these cards" and "Review last hand".
- **Reveal**: `{"cmd":"reveal","risk":R,"bluff_pct":B}`, answered by the route.
  - The server checks all of these:
    - there is a Mystery game, not yet revealed;
    - 3 finished hands, or game over;
    - whole numbers, with Risk 0-100 and Bluff 0-60.
  - Anything else gets a 400, also outside Mystery mode. Only one guess per game counts.
  - The reply has the real settings, the guess, how far off each part was (`off`) and the full state. After it,
    nothing is hidden.
- **The secret is cleared:**
  - when a new game is accepted. A new game that Lean rejects keeps the old game, and it stays hidden.
  - when the engine is lost (exit, hang or restart). The secret is tied to the program that holds the game.
- **Guess panel** (`MysteryGuess.tsx`): two sliders.
  - It opens on its own after the third finished hand, and at game over. A top-bar button opens it too, and shows
    "1/3" until you may guess.
  - After the reveal, it shows a table of your guess, the real values and the difference, plus "Review last hand".
- **Modes stay separate.** Normal, practice and Mystery are one `Game.mode` value, set when a game starts. The route
  knows only Mystery or not, and any accepted non-Mystery `new_game` ends a Mystery game.
- **Normal games are unchanged.** Their replies, seeds, replays, reviews and lost-engine behavior are as job 1 left
  them. The normal path now builds its reply through `publicReply`, with the same content. Job 1's route tests and a
  new normal-game test pass.
- `mystery.test.ts` checks every reply of a played Mystery game. The game includes state, peek, illegal moves,
  reviews and next hand. Each reply must have:
  - no hidden key: `sliders`, `botReasons`, `bot_reasons`, `review`, `label`, `worth_bb`, `equity_had`,
    `equity_needed`, `range`, `risk_explorer`;
  - no "Risk" or "Bluff" followed by a number;
  - a null seed.

  It also checks the early reveal (400), seven bad guesses (400), a good reveal, a second reveal (400), the seed
  hidden at game over, clearing on a new game and on engine loss, and normal games.

## ReviewModal props before job 4's merge

- `PokerApp.tsx` passes `hideSliderInfo` and `onShowProof` in a typed spread:
  `<ReviewModal {...reviewExtras} ... />`, where `reviewExtras: ReviewModalExtras` declares the two optional props
  exactly as the contract says.
  - Today, TypeScript accepts the spread and job 1's `ReviewModal` ignores the two props.
  - Once job 4's `ReviewModal` declares them, TypeScript checks the spread against them.
  - No `any`, no `@ts-ignore`, and nothing pretends to work.
- Job 4's local `ReviewModal.tsx` (uncommitted when I looked, about 01:00) declares the same two props with the same
  types.
- `hideSliderInfo` is true only while a Mystery game is unrevealed. The review never opens then, so the prop is extra
  protection.

## Integration that needs other merges

1. **Job 4 (`review-insights`).**
   - The "Why can I trust this?" links appear only after its `ReviewModal` merges. They then open this drawer at
     `review`, `bluff` or `risk`.
   - Both branches add types at the end of `src/lean/protocol.ts`. Keep both blocks.
2. **Practice verdict inside the review.** Today the T8 sentence floats in a bar above the open review, because I may
   not edit `ReviewModal.tsx`. A cleaner home is inside the review: for example, an optional `note` prop on
   `ReviewModal` after job 4 merges.
3. **Job 3 (`release-docs`).** After its merge, `docs/demo/challenges.json` and `src/lib/challenges.ts` hold the same
   spots. If `find-demo-hands.mjs` is rerun on the merged engine and the spots change, update both. A test that
   compares the two files could be added once both are on main.
4. **New theorems from job 2 or Aarav.**
   - The drawer lists only what is in Comparator at `df6904a`.
   - The test fails if a listed theorem is renamed or removed. It does not fail when a new theorem is not listed.
   - Add new entries in the morning.
5. **Stale tab** (job 1 skipped step 11). The Mystery secret belongs to the server's one game, not to a browser tab.
   A second tab that starts a game replaces it, as with any game.

## Choices I made alone (headless; safer or smaller option)

- **Peek stays available in Mystery games.** It shows the bot's cards, not its settings, but it makes the guess
  easier. Devom can turn it off for Mystery games if that is preferred.
- **One guess per game.** A second reveal gets 400.
- **Only `mystery: true` is accepted.** Any other `mystery` value gets 400.
- **The entire review is deferred before the reveal**, including your own ungraded moves. This is simpler than
  sending parts of it, and nothing in it can leak.
- After a revealed Mystery game, "Replay these cards" starts a normal game with the real sliders and the seed.
  "New game" deals a new Mystery bot.

## For Devom to look at

1. **Drawer.** Click "What is guaranteed?" in the top bar. Check the 8 entries, their words, and the "What we trust"
   list at the end. Escape closes it.
2. **Catch a bluff.**
   - It loads at the river with the prompt.
   - Call. When the hand ends, the review opens on its own, and the line under the table says "Lean graded your
     call: Best."
   - Try again, and fold: "Inaccuracy".
3. **Avoid a bad call.** Call gives Mistake; fold gives Best.
4. **Make the right decision and still lose.** Call. The bot wins the showdown, the review shows Best, and the line
   floating above the review reads the T8 sentence. Check that it does not cover anything important in the review.
5. **Mystery.**
   1. Tick "Mystery opponent". The presets, sliders and seed field go away.
   2. Start. The top bar says "Bot Mystery · hidden until you guess", and the bot is "Mystery bot".
   3. Press R or Review after hand 1. A note says reviews open after the guess.
   4. After hand 3, the guess panel opens. Guess, and check the table of guess, real value and difference.
   5. The top bar now shows the real sliders, and the review shows grades and reasons.
6. **Mystery game over.** Shove every hand. The game-over screen shows "hidden until you guess" and "Guess the bot".
   After the guess, the seed and sliders appear, and "Replay these cards" is offered.
7. **A normal game** looks and behaves as before, apart from the "What is guaranteed?" button.

## For the docs (guarantee texts, to check against job 3's pitch claim table)

These are the drawer's exact texts, from `src/lib/guarantees.ts`.

- **T1. Chips are never created or destroyed.**
  - After every move the engine accepts, the stacks, the pot and the bets add up to the same number of chips as
    before.
  - A new hand holds exactly the chips the two players brought to it.
  - So every game always has exactly 1,000 chips.
  - Theorems: `step_keeps_chips`, `startHand_keeps_chips`, `chips_always_1000`.
  - Assumes: the game started as a new game and then changed only by moves and new hands that the engine accepted.
  - Not covered: it is about the engine's own game state. It does not check the numbers the web page shows.
- **T2. No card is dealt twice.**
  - The shuffle only changes the order of the cards. Nothing is added, lost or copied.
  - Every shuffled deck has the 52 cards of a new deck.
  - In every game, the cards on the table (both players' cards and the board) are all different, and all come from
    that deck.
  - Theorems: `shuffle_same_cards`, `shuffle_fair`, `no_card_dealt_twice`.
  - Assumes: as T1.
  - Not covered: it does not say every order of the deck is equally likely. The shuffle uses a seed, so the same seed
    always deals the same cards.
- **T3. Only legal moves are accepted.**
  - If the engine accepts a move, the rules allow it.
  - If a move breaks the rules while the hand is still going, the engine rejects it with "illegal move" and makes no
    new hand.
  - In every game, the player whose turn it is has chips and has not bet more than the other player.
  - Whenever the player to act may act, the bot's move is legal, at every slider setting.
  - Theorems: `accepted_move_is_legal`, `illegal_move_rejected`, `player_to_act_may_act`, `botDecide_legal`.
  - Assumes: the rules are the ones written in `Legal` (`engine/Poker/Spec/Basics.lean`). For a rejection, the hand
    is not over yet.
  - Not covered:
    - The buttons and raise limits on the page come from code that is not proved to match the rules. The engine
      still rejects any illegal move it gets.
    - The code that keeps the game between requests is not covered.
- **T4. More Risk never turns a fold into a call.**
  - In one spot, if the bot calls or raises at some Risk, it also calls or raises at every lower Risk.
  - The bot calls exactly when the call, weighted by Risk, is worth at least as much as folding.
  - A lost chip counts 1 + Risk/50 times: once at Risk 0, twice at Risk 50, three times at Risk 100.
  - A call that can never lose chips is taken at every Risk.
  - Theorems: `risk_monotone`, `botDecide_risk_monotone`, `callPays_iff_takes`, `bot_calls_only_when_worth_it`,
    `bot_folds_only_when_not_worth_it`, `more_risk_takes_fewer_gambles`, `no_loss_always_taken`.
  - Assumes: the same spot (the same game state, cards, Bluff setting and win, tie and loss counts). For the call
    rule, the amount to call is not more than the pot.
  - Not covered:
    - It compares one decision at a time. It says nothing about whole games, or how often a bot wins.
    - It holds for any win, tie and loss counts. It does not say the counts are exact on the flop or preflop.
- **T5. The review grades call and fold correctly, under its model.**
  - A graded call or fold is Best exactly when it was worth at least as much as the other choice.
  - A decision that lost fewer big blinds never gets a worse label.
  - The worths shown are the exact averages over the bot's possible hands, in big blinds. Folding is worth 0.
  - Calling is Best exactly when the equity you had is at least the equity you needed.
  - Theorems: `review_worth`, `review_lost`, `review_best_iff`, `review_label_monotone`, `review_call_best_iff_equity`.
  - Assumes:
    - The bot's possible hands are every hand its river rule bets with on that board, minus the hands that use your
      cards. Each one counts the same.
    - For the worths and equities, the bot can hold at least one hand, and calling costs chips.
  - Not covered:
    - Only your call or fold after the bot's first river bet is graded. Raises and other streets are not.
    - The model ignores the earlier betting, so it only estimates what the bot really holds.
    - It makes no claim about raising.
- **T6. The exact counts look at every outcome once.**
  - On the river, the bot counts each two-card hand the other player could hold exactly once: 990 hands.
  - On the turn, it counts each pair of a river card and such a hand exactly once: 45,540 outcomes.
  - Each outcome is scored with the rules' own showdown.
  - Theorems: `enumeration_exact`, `riverOpponentHands_length`, `turnOutcomes_length`, `countsFor_river`,
    `countsFor_turn`.
  - Assumes: for the totals, two hole cards and five (river) or four (turn) board cards, all different.
  - Not covered:
    - Flop counts are estimated from 1,000 seeded deals, and preflop counts come from a table. Neither is covered.
    - Every hand counts the same. The counts do not use the betting so far.
- **T7. The Bluff slider sets the bluffs in the river betting set.**
  - On a river board, the bot's river betting set has 324 value hands.
  - Its number of bluffs is the whole number nearest to the one that makes bluffs b% of the set, with halves rounded
    up.
  - No hand is both a value hand and a bluff.
  - With no bet to face on the river, the bot bets exactly the hands in this set.
  - Theorems: `bluff_frequency`, `value_and_bluffs_apart`, `bot_bets_its_set`.
  - Assumes: the board has five different cards, and Bluff is 0 to 60.
  - Not covered:
    - It is about the set of hands, not how often the bot bluffs in played games.
    - Your cards, the earlier betting and luck change what you see at the table.
- **T8. The grade ignores the bot's real cards.**
  - Two hands that look the same to you get the same review, whatever cards the bot really holds.
  - The bot's real hand is one of the hands the review counts.
  - Theorems: `no_hindsight`, `bot_hand_in_review`.
  - Assumes:
    - "Look the same" means the same chips, the same board and your same two cards.
    - For the second theorem, the bot's cards are ones it bets with on that board, and they are not your cards.
  - Not covered: a right decision can still lose chips. The grade looks at the decision, not the cards that came.
- **What we trust:**
  - The Lean 4.35 kernel, which checks the proofs, and the Lean compiler, which builds the engine the app runs.
  - Three standard axioms: `propext`, `Quot.sound` and `Classical.choice`.
  - The rule definitions the theorems use, such as `Legal`. A person must read them to check they say the right
    thing.
  - The preflop table: win, tie and loss counts estimated from random deals. It is data, not a proof.
  - The web app and the JSON layer: the page, the server route and the code that turns the game into JSON. No proof
    covers them.

What the three features do, in plain words:

- **"What is guaranteed?"** lists each proved property in plain words, with its Lean theorem names, what it assumes
  and what it does not cover, and what we trust without proof.
- **Practice challenges** load three rehearsed hands at the river decision. You call or fold, and Lean's review
  grades the choice.
- **Mystery opponent.** The server picks the bot's Risk and Bluff at random and keeps them secret. The settings, the
  seed, the bot's reasons and the reviews stay hidden until you guess. You may guess after 3 finished hands, or at
  game over. The reveal shows how close you were.
