Build path changed: yes. `npm run build` no longer touches the network (system fonts instead of Google's Inter; next.config.ts turns off Next's telemetry and its default build-time npm security check). Compiling `engine/Main.lean` now runs `git rev-parse` and `git status` once, to record the engine's build commit. Makefile, package.json, lockfiles, toolchain files and scripts/ are unchanged.
Ready for dependent jobs: yes

# Job 1 report: web app hardening (branch `web-hardening`)

Worktree `C:\Coding-Projects\vc-web`, branched from `origin/main` at df6904a. The worktree and its
built engine (`engine\.lake\build\bin\poker.exe`, reports `engineCommit` 42f4b26) are left in place.

## Checks run on the final code (42f4b26)

- `cd engine && lake build`: passes (93 jobs).
- `npm run typecheck`: clean.
- `npm test`: 14 files, 230 tests, all pass. Baseline was 13 files, 217 tests. The 13 new tests are
  listed under each step.
- `npm run build`: passes. A Node preload logged every DNS lookup, TCP connect and `fetch` made by
  the build and its workers: none. (It cannot see network use from Turbopack's Rust code.) `.next`
  holds no Google font references.
  - Worktree only: `node_modules` here is a junction into the main checkout, and Turbopack refuses
    to read outside its root. For this check, a script added `turbopack.root` to `next.config.ts`
    and restored the file afterwards. The committed config has no such line. Jobs 4 and 5 will hit
    the same error in their worktrees; in the main checkout it does not arise.
- HTTP smoke test on `next start` (port 3917, stopped afterwards): page loads with no Google fonts;
  new game, peek, plain state, bad peek (400), fold and review all answer as expected; replies carry
  `turnMode` "exact", `engineCommit` 42f4b26 and `serverCommit` 42f4b26.
- Not run: `make install` / `make run` (no make on this PC), `checks/audit.sh`, Comparator, and a
  look at the screens in a browser.

Heavy commands ran one at a time under the named mutex `Local\VibeCheckHeavyWork`, after waiting for
any outside `lake`/`lean` build.

## Steps

| Step | Status | Commits |
| --- | --- | --- |
| 1. Baseline | done: lake build, typecheck, 217/217 | none |
| 2. Offline-safe build | done | 66efd4f |
| 3. Engine loss | done | 184a770 (see note) |
| 4. Displayed pot | done | 184a770 |
| 5. Fold from Lean | done | fec113e |
| 6. Replay record | done | 3c60fd3 (Lean), d4fc65e |
| 7. Peek at bot's cards | done | 3c60fd3 (Lean), 0cacbab |
| 8. `bot_reasons` type | done | cdd3f42 |
| 9. No TypeScript prototype in the browser | done | 3a46a19 |
| 10. No silent skips | done | 42f4b26 |
| 11. Stale tab (stretch) | skipped | none |

Note on 184a770: a commit message with double quotes broke under PowerShell 5.1, so the step 3
commit failed and its files went into the step 4 commit ("Show the whole pot on every street"). I
split them locally, but the force-push to fix the branch was denied, so 184a770 holds steps 3 and 4
together. Its message describes only step 4. Step 3 is the 9 files other than `Table.tsx`.

Step 11 was skipped to hand off sooner, as asked. It would also change `route.ts` and `useGame.ts`,
which job 5 owns next. Suggested shape for later: `new_game` returns a random `gameId`; the route
checks it on every other command inside a one-at-a-time queue, and answers a stale id with
`lost: true` (HTTP 409).

### What each step did

- **2.** `layout.tsx` drops `next/font/google`; `globals.css` uses a system font stack. The
  description now says: "Heads-up no-limit Texas Hold'em against one bot you build with two sliders,
  Risk and Bluff." `next.config.ts` sets `NEXT_TELEMETRY_DISABLED` and `experimental.agentUpgrade:
  false`. That second one matters: Next 16 asks the npm registry for advisories on every build by
  default. The build prints "Experiments: ⨯ agentUpgrade", which is expected.
- **3.** Engine exit, hang (reply timeout) or failed start: the request in flight gets
  `{"error":"The game engine stopped. Start a new game.","state":null,"lost":true}` (HTTP 503). Later
  commands that need the lost game get the same body (HTTP 410), every time, until a new game.
  - A malformed request still gets HTTP 400 with `state: null` and no `lost`. The browser shows the
    error and keeps the game.
  - `useGame` marks a game lost only when `lost` is true. Then it shows the message and a "New
    game" button that goes back to the setup screen. All action buttons, Next hand, Review and the
    keyboard keys are off.
  - `POKER_REPLY_TIMEOUT_MS` sets the 30 s limit.
  - Tests (4): a stand-in that exits at once, a stand-in that never answers (300 ms limit), a real
    engine killed mid-game, and a malformed request that keeps the game. Stand-ins are in
    `src/lean/__fixtures__/`. `LeanProcess` runs a `.mjs` POKER_BIN with Node.
- **4.** The middle shows Lean's `pot` plus both players' current `bet`, on every street.
- **5.** The Fold button and the F key use `legal.fold`.
- **6.** Lean's state has `"turnMode":"exact"` (comment points to the "Turn: exact" note in
  `Equity.lean`) and `"engineCommit"`. `Main.lean` reads the commit with git while it compiles. It is
  "unknown" if git fails or if any file under `engine/` differs from that commit.
  - The route adds `"serverCommit"`: `git rev-parse --short HEAD`, run once when the server starts,
    "unknown" on failure. The two commits can differ, and the screen shows both.
  - The game-over screen shows: seed, Risk, Bluff, turn mode, engine build, server checkout.
  - Test (1): the fields are present at the start, on an error reply and at game over.
  - Lake recompiles `Main.lean` only when the Lean code changes. After a commit that leaves Lean
    unchanged, the binary keeps its old commit, which is still correct. A build made from changed
    files says "unknown" until Main is compiled again. I forced one rebuild after committing, so the
    binary left here says 42f4b26.
- **7.** A "Peek at bot's cards" checkbox in the top bar. It is off by default and off again at
  every new game and when you leave the table.
  - While it is on, every command carries `"peek": true`, and Lean's state includes the bot's
    cards. Lean does this only in `stateJson` (`Protocol.lean`). `Session` is untouched.
  - Turning it on sends `{"cmd":"state","peek":true}`. Turning it off hides shown cards at once,
    then refreshes from Lean without peek. A reply already on its way when it goes off has its bot
    cards dropped.
  - Peeked cards are dimmed, with a "👁 Peeked" label. At a real showdown they show normally.
  - The review says "You peeked at the bot's cards this hand. The grade assumes you didn't know
    them." for hands where the toggle was on while the hand was played.
  - Seed and detailed reasons stay hidden until hand end, as before.
  - A non-boolean `peek` gets HTTP 400 at the route. Lean also rejects it, with the game unchanged.
  - Tests (5): no peek gives `null` bot cards mid-hand, while peek gives two cards (seed and reasons
    still hidden); the same seed and moves, peeking and not, give equal states and reviews apart from
    the bot's cards; three bad `peek` values get 400.
- **8.** `LeanReview.bot_reasons` added. The review screen now shows the review's own reasons, so
  they always match the reviewed hand. `ReviewModal` no longer takes a `botReasons` prop.
- **9.** `src/lib/cards.ts` (Card, rankOf, suitOf) and `src/lib/table.ts` (the shapes the table
  draws, and potTotal). Unused fields are dropped. New test `src/lib/no-prototype.test.ts` (1)
  fails if shipped code imports the prototype. The grep, run on the final code:

  ```
  $ grep -rnE "from ['\"]@/(engine|ai|review)|from ['\"]\.\.?/(\.\./)*(engine|ai|review)" src/app src/components src/hooks src/lib src/lean
  src/lean/program.test.ts:3:import { type Action, type HandState, applyAction, handSeed, seededDeck, startHand } from "@/engine";
  ```

  The one hit is a test that replays Lean's games in the prototype as a reference, which is allowed.
- **10.** Both Lean suites start with a "finds the built Lean program" test (2). With POKER_BIN set
  to a missing file, both files fail with the build command in the message. With `SKIP_LEAN=1` as
  well, they are skipped.

## For jobs 4 and 5

- Engine: `C:\Coding-Projects\vc-web\engine\.lake\build\bin\poker.exe`.
- `ApiReply` (protocol.ts) is Lean's reply plus `lost?: true`. `LeanCommand` takes an optional
  `peek`. `LeanState` has `turnMode`, `engineCommit` and `serverCommit?`. `LeanReview` has
  `bot_reasons`.
- `ReviewModal` props are now `review`, `peeked?` and `onClose`. Job 4 adds `hideSliderInfo?` and
  `onShowProof?`. Hide `review.bot_reasons` in Mystery mode.
- `GameOver` has a new `replay` prop (Risk and Bluff come from `game.lean.sliders`). Job 5 hides
  them there in Mystery mode.
- `useGame` also returns `peek`, `peekedHands` and `setPeek`. A `Game` has `lost` and `peeked`.
- `npm run build` in a worktree needs the `turbopack.root` workaround above, uncommitted.

## For Devom to look at

1. The table from the flop on: the pot in the middle includes this street's bets.
2. A spot with nothing to call: Fold is enabled.
3. Peek on mid-hand: the bot's cards flip face up, dimmed, with the "Peeked" label. Peek off: they
   go face down at once. Start a new game: the box is unticked.
4. The review of a peeked hand shows the yellow note. An unpeeked hand does not.
5. The game-over screen: the replay record line under the buttons.
6. Engine loss: start a game, end `poker.exe` in Task Manager, then click a move. Expect "This game
   was lost" with one "New game" button.
7. The page font: system font now, not Inter.

## For the docs

- The app builds and runs without internet. It uses the computer's own fonts, and the build sends
  no usage data and asks no package registry anything.
- If the game engine stops or hangs, the game is lost. The screen says "The game engine stopped.
  Start a new game." and offers only a new game. A bad request does not end the game.
- "Peek at bot's cards" is an optional switch, off by default and off again in every new game. It
  shows the bot's two cards during the hand, so you can watch how it plays its sliders. Lean adds the
  cards to its reply; peeking changes nothing in the game, the seed or the bot's reasons. The review
  marks peeked hands and still grades as if you could not see the cards.
- The game-over screen shows the replay record: seed, Risk, Bluff, turn mode (always exact), the
  commit the engine was built from, and the commit the server runs from. "unknown" means that
  commit could not be told, for example after building from changed files.
- The table's pot counts this street's bets too.
- Fold is always offered when Lean allows it, also when you could check.
- The browser no longer loads the TypeScript prototype (src/engine); it is a test reference only.
- `npm test` fails if the engine is not built. `SKIP_LEAN=1` skips those tests on purpose.
- New environment variables: `POKER_REPLY_TIMEOUT_MS` (reply limit, default 30000) and `SKIP_LEAN`.
