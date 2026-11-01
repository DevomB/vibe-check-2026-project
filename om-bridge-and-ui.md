# Task for Om: Node-to-Lean bridge, Lean game loop, browser UI

Paste this whole file into your LLM. Also give it `docs/tasks/README.md` (team plan and shared
contract), `MVP.txt` sections 2, 4, 6, 7 and 13, and `CLAUDE.md`.

## Context

We are building a heads-up no-limit Texas Hold'em web app for the Vibecheck 2026 hackathon. The
game engine is written in Lean 4.35 (`engine/`) and its properties are proven there. The
browser (Next.js, `src/`) must contain **no game logic**: it sends the human's clicks to a Lean
program and draws Lean's replies. The bot has two sliders, Risk (0-100) and Bluff (0-60%). After
each hand, a review grades the human's river call/fold decisions.

You own the path from the browser to Lean and back, plus all UI. Teammates write the Lean bot
(Devom, `Engine/Slider.lean`), the river review (Aarav, `Engine/Review.lean`) and the proofs
(Vishal). You call their functions; you do not write them.

## Where you start

Branch `origin/lean-bridge` (your WIP) is already merged with `main`'s `engine/` layout. It was
checked at 3:45 PM: `cd engine && lake build` passes (27 jobs), and the program answers
`new_game`, `act`, `bot` correctly. It has `engine/Main.lean` (JSON loop), `engine/Engine/Bot.lean`
(always-call bot, `legalOptions`, `botMove_legal` proof), `src/lean/` (process + protocol),
`src/app/api/game/route.ts`, a rewired `src/hooks/useGame.ts` and `src/lean/program.test.ts`.
The browser side was not tested.

## Files you own

`engine/Main.lean`, `engine/Engine/Session.lean` (new), `engine/Engine/Bot.lean`,
`engine/Engine/BotTests.lean`, `src/lean/`, `src/app/`, `src/hooks/`, `src/components/`,
`src/lib/`, `Makefile`, `package.json`. Do not edit other people's files or `engine/Poker/Spec/`.

## Steps, in order

### 1. Merge `lean-bridge` (target 4:30 PM)

- `npm ci`, `make lean`, `npm test` (includes `src/lean/program.test.ts`), `npm run typecheck`.
- `npm run dev`; play two full hands in the browser, including a fold and a showdown.
- Fix what breaks, then merge into `main` and delete the branch.

### 2. Lean runs the bot (target 5:30 PM, Checkpoint A)

MVP §7: "After new_game, a valid act, or next_hand, Lean runs the bot and automatic street
transitions until the next human decision or hand end, then returns one state response.
JavaScript does not decide bot actions."

- Move the game loop out of `Main.lean` into a pure `engine/Engine/Session.lean`, so it can be
  tested with `#guard` and later proven about. `Main.lean` stays thin: parse a line, call the
  session, print a line.
- After every accepted human command, loop: while the hand is not over and it is the bot's
  turn, call the bot and `step`. Give the loop a fuel bound (a hand has fewer than 200 moves) so
  it is a total function, not `partial`.
- Delete the `bot` command from Lean, `src/lean/protocol.ts`, the route and `useGame`. Keep the
  `events` list so the UI can still animate each bot move one at a time.
- Call the bot through Devom's `botDecide sl seed (h.hole 1) h.board h.chips` from
  `Engine/Slider.lean` (a stub that checks or calls will be on `main` by 4:30 PM). Use
  `handSeed g.seed g.handNo` as the seed; never take randomness from the shuffle.
- A rejected command returns `{"error": ..., "state": <unchanged>}` and changes nothing (T3
  depends on this).
- **Checkpoint A:** play a full hand in the browser against the Lean bot. Tell the team.

### 3. Sliders and the review command (target 8:30 PM)

- `new_game` takes `"risk"` (0-100) and `"bluff_pct"` (0-60). Reject values out of range with
  an error. Store them in the session as `Sliders`.
- Detailed bot reasons: keep each `BotChoice.reason` in the session, and send them in the state
  **only once the hand is over** (MVP §2: live messages stay generic, like "Bot bets 60").
- Review snapshots: right after the bot makes an **opening** river bet (it faced no bet and
  chose `raiseTo`) and the human is to act, record `riverSpotOf h sliders.bluffPct` (Aarav's
  function). When the human then calls or folds, store `(spot, choice)` under that hand number.
  If the human raises instead, store nothing for that decision: raises are not graded.
- `{"cmd":"review","hand":N}` returns, for each stored decision, the fields of MVP §13:
  `street`, `your_action`, `label`, `worth_bb {call, fold}`, `equity_had`, `equity_needed`.
  Compute the verdict with Aarav's `reviewRiver`; turn the exact fractions into JSON numbers only
  here, for display. A review does not change the game and uses no randomness.
- Every ungraded decision shows "not graded yet".

### 4. UI (target 9:30 PM, Checkpoint B)

- Setup screen: replace the opponent picker with two sliders, Risk 0-100 and Bluff 0%-60%, with
  one plain sentence each under them (MVP §3), plus Start. Keep the seed field for replays.
- Table: unchanged, except the bot's live messages are generic.
- After a hand: a "Review" button opens the review screen: each graded decision with its label
  (Best, Good, Inaccuracy, Mistake, Blunder), what call and fold were each worth in big blinds,
  and equity had vs equity needed. Also show the bot's detailed reasons for that hand.
- Next Hand only when status is "hand over"; nothing after "game over".
- **Checkpoint B:** a full game in the browser vs the slider bot, with the review grading at
  least one river decision. Rehearse one such hand and write its seed and moves into
  `docs/tasks/STATUS.md`. Devom needs this for the pitch.

### 5. Sunday morning: make it run anywhere (done by 12 PM)

- Fresh clone, then `make install && make run` must work (MVP §7, RULES.md). `make install`
  builds the `poker` executable and runs `npm ci`; `make run` builds and starts Next.js and
  opens the browser. Test it on a fresh clone on Windows, and on Linux/WSL (Vishal can help).
- Remove dead TypeScript game logic from the browser path. `src/engine/` may remain only as a
  test reference and for type definitions, as on `lean-bridge`.

## Checks before each merge to `main`

- `cd engine && lake build` passes, with no `sorry` warnings in your files.
- `npm test` and `npm run typecheck` pass.
- You played the change in the browser.
- No game rule decided in TypeScript. The browser never computes legality, bot moves, winners
  or review labels.

## Using the extra credits on this task

- One main session for the bridge and game loop. A second session in its own worktree for UI
  (setup sliders, review screen) once Checkpoint A is merged. A cheaper model is fine for UI.
- Run `/code-review high` on your branch before each merge to `main`.
- Overnight (10 PM): one cloud session on Linux that does a fresh clone, `make install &&
  make run`, plays a scripted game through `/api/game`, and reports anything broken. It works
  on a branch; you review it in the morning.
