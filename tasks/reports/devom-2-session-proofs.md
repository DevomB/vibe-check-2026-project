Build path changed: no

# Devom job 2: Lean proofs about the game loop the app runs

Branch `session-proofs` (from `origin/main` at `df6904a`), worktree `C:\Coding-Projects\vc-session`.
Pushed. Not merged to `main`.

**Short version.** All four statements, (a) to (d), are proved as written, with no proof holes,
no new axioms and no `native_decide`. Each one is in `Checks/Challenge.lean` and
`comparator.json`. The `botMove` fallback in `Session.runBot` is removed. It was first proved
unused in the app. `npm test` passes 217 of 217 before and after every commit. The examples
file and the stricter audit are done too.

The build and install files are untouched (`Makefile`, `package*.json`, `lean-toolchain`,
`lakefile.toml`, `lake-manifest.json`, `scripts/`). `engine/Engine.lean` now imports two more
proof modules, `Engine.Proofs.Session` and `Engine.Proofs.Examples`. This is the minimum needed
for `lake build` to build them.

## Commits (one per item, in order)

| Commit | What |
|---|---|
| `323a161` | (c) `bot_move_accepted`, plus `Session.botChoice_accepted`. New `Engine/Proofs/Session.lean` starts with the four statements in plain words and in Lean. |
| `a632cdc` | (b) `handle_keeps_reachable` |
| `87e93d6` | Removes the `botMove` fallback from `Session.runBot` (no change in behaviour, see below) |
| `45506f6` | (a) `handle_error_unchanged`, plus `app_game_reachable` (not registered) |
| `d28d2f2` | (d) `viewOf_toCall_le_pot` (in `RiskUtility.lean`, theorems only) |
| `5a6a30b` | `Engine/Proofs/Examples.lean`: examples with every hypothesis met, and bad outputs rejected |
| `f730ca7` | Stricter `checks/audit.sh` |
| (this one) | This report |

## Statements for Devom to approve

The Lean in each block is the exact text in `Checks/Challenge.lean`. It is the same text as
the proved theorem (checked word for word, see "Checks").

### (c) `bot_move_accepted`, commit `323a161`, `Engine/Proofs/Session.lean:105`

Plain words: in a game the engine can reach, while the hand is not over, the engine accepts the
move the slider bot picks, for any sliders, seed and cards.

```lean
theorem bot_move_accepted (g : Game) (hg : g.Reachable) (hnot : g.hand.ended = none)
    (sl : Sliders) (seed : Nat) (hole board : List Card) :
    ∃ h', step g.hand (botDecide sl seed hole board g.hand.chips).action = .ok h'
```

Note: there is no "the bot is to act" assumption. The theorem holds for whichever player is to
act, so it is stronger than the task's wording. The session form,
`Session.botChoice_accepted` (`Session.lean:114`, not registered), uses the app's own inputs:
if `s.game.Reachable` and `s.botToAct = true`, then `∃ next, s.move s.botChoice.action = .ok next`.

### (b) `handle_keeps_reachable`, commit `a632cdc`, `Engine/Proofs/Session.lean:187`

Plain words: suppose the session's game is reachable, or there is no game yet. If
`Session.handle` accepts a command, the new session's game is reachable too.

```lean
theorem handle_keeps_reachable (cur : Option Session) (c : Command) (s' : Session)
    (hcur : ∀ s, cur = some s → s.game.Reachable)
    (hok : Session.handle cur c = .ok s') :
    s'.game.Reachable
```

The assumption `hcur` is needed, and it is stated on purpose. A `state` command accepts any
session and keeps its game, even a broken one. `Examples.lean` shows this with a 2,005-chip
session. The next theorem removes the assumption for the app.

**Extra, proved but not registered:** `app_game_reachable` (`Session.lean:282`, commit
`45506f6`). This is the statement that makes T1 and T2 cover the app's game. Start from no game
and answer any request lines in order, as `Main.lean` does. Whenever there is a game, it is
reachable, so `chips_always_1000` and `no_card_dealt_twice` apply to it.

```lean
theorem app_game_reachable (lines : List String) (s : Session)
    (hs : lines.foldl (fun cur line => (respond cur line).1) none = some s) :
    s.game.Reachable
```

`Main.lean` trims each line and skips empty ones before it calls `respond`. The `lines` here are
the lines that reach `respond`. If you approve it, register it in Challenge and comparator.

### (a) `handle_error_unchanged`, commit `45506f6`, `Engine/Proofs/Session.lean:234`

Plain words: if a request line holds a game command and `Session.handle` rejects it, `respond`
keeps the session exactly as it was. The reply is the error message and the table as it was
before, with no new events.

```lean
open Lean (Json toJson) in
theorem handle_error_unchanged (cur : Option Session) (line : String) (j : Json)
    (c : Command) (e : String)
    (hjson : Json.parse line = .ok j) (hreq : parseRequest j = .ok (.game c))
    (hrej : Session.handle cur c = .error e) :
    respond cur line =
      (cur, Json.mkObj [("error", toJson e),
        ("state", match cur with
          | some s => stateJson { s with events := #[] }
          | none => Json.null)])
```

Why it has this form:
- It describes the real command and reply path: `respond`, the function `Main.lean` calls for
  each line. It is not only about `Session.handle`, whose error case has no session in it.
  The first part of the result is the session the app keeps (`cur`, unchanged). The second
  part is the exact reply.
- The `state` in the reply is the old session with its event list emptied. This is exactly
  what a `state` command would show next, because `Session.handle (some s) .state` gives
  `{ s with events := #[] }` by definition.
- `Json.parse` is a `partial def` in Lean's library, so no proof can work out what it returns.
  So the parsed JSON `j` is a hypothesis, and the theorem holds whatever `Json.parse` returns.

**Extra, proved but not registered:** `respond_keeps_session_unless_accepted`
(`Session.lean:247`). Every line other than an accepted game command keeps the session: bad
JSON, an unknown command, a review, or a rejected command.

```lean
theorem respond_keeps_session_unless_accepted (cur : Option Session) (line : String) :
    (respond cur line).1 = cur ∨
    ∃ j c s, Json.parse line = .ok j ∧ parseRequest j = .ok (.game c) ∧
      Session.handle cur c = .ok s ∧ (respond cur line).1 = some s
```

### (d) `viewOf_toCall_le_pot`, commit `d28d2f2`, `Engine/Proofs/RiskUtility.lean:91`

Plain words: in every state, the chips the bot must add to call are at most the pot it can win.
So `bot_calls_only_when_worth_it` and `bot_folds_only_when_not_worth_it` apply to every real
decision of the bot.

```lean
theorem viewOf_toCall_le_pot (sl : Sliders) (hole board : List Card) (s : State) :
    (viewOf sl hole board s).toCall ≤ (viewOf sl hole board s).pot
```

Note: this holds in every state, reachable or not, so the task's "in every reachable hand
where the bot acts" is not needed. The reason: the call is capped at the other player's bet
minus the bot's own, and the pot it can win already includes the other player's bet up to what
the bot can match. `Examples.lean` applies it to the real bot. For any sliders, seed, cards and
state, if `botDecide` calls, then the call is worth it at its Risk; if it folds, then it is not.

### What a reviewer must read (the trusted surface)

- (a): `respond`, `parseRequest`, `stateJson` (`Protocol.lean`), `Session.handle`, `Command`.
- (b): `Session.handle` and what it runs (`Session.start`, `Session.dealt`, `Session.humanAct`,
  `Session.move`, `Session.runBot`), `Game.Reachable` (`Proofs/Reachable.lean`), `newGame`,
  `Game.act`, `Game.nextHand`, `step`.
- (c): `Game.Reachable`, `step`, `botDecide` (and the definitions listed in `Proofs/BotSpec.lean`).
- (d): `viewOf`, `State.toCall`, `State.potToWin`.

## The fallback in `Session.runBot`: removed (commit `87e93d6`)

Old code (`Session.lean:162-172` at `df6904a`):

```lean
    let c := if (s.move c.action).toBool then c
      else ⟨botMove h.chips, "Check or call: the planned move was not allowed."⟩
    match s.move c.action with
    | .error _ => s   -- never happens: see above
```

New code: the `let c := if ...` line is gone. The `.error _ => s` branch has to stay, because
`Session.move` returns an `Except`. Its comment now cites the proof that it is never taken.

Why the app's behaviour did not change:
1. `Session.botChoice_accepted`: in a session whose game is reachable, the engine accepts the
   bot's move. So the old test `(s.move c.action).toBool` was always true on such sessions.
2. In the app, `runBot` only runs on such sessions. `app_game_reachable` shows the app's session
   always has a reachable game. `Session.start`, `next_hand` and `Session.humanAct` call
   `runBot` only on a reachable game. `Session.runBot_reachable` shows each bot move keeps the
   game reachable.
3. A scratch proof compares the new `runBot` with a copy of the old one. On every session
   whose game is reachable, they give the same result. Its axioms are `propext`,
   `Classical.choice` and `Quot.sound`. It was checked against `87e93d6` and again against
   `f730ca7`. It is not committed, because it holds a frozen copy of the old `runBot`: any
   later change to `runBot` (job 4 adds a `HandLog` field) would break the build. To re-check
   it, put this in a file next to `engine/` and run `lake env lean <file>`:

```lean
import Engine

/-- `Session.runBot` as it was before the fallback was removed (commit a632cdc). -/
def runBotBefore : Nat → Session → Session
  | 0, s => s
  | fuel + 1, s =>
    if !s.botToAct then s else
    let h := s.game.hand
    let c := s.botChoice
    let c := if (s.move c.action).toBool then c
      else ⟨botMove h.chips, "Check or call: the planned move was not allowed."⟩
    match s.move c.action with
    | .error _ => s
    | .ok next =>
      let next := next.logHand fun l => { l with reasons := l.reasons.push c.reason }
      let h' := next.game.hand
      let opensRiver := h.board.length == 5 && h.chips.toCall == 0 && c.action matches .raiseTo _
      let next := if opensRiver && h'.ended.isNone && h'.chips.toAct == human then
          { next with riverSpot := some (riverSpotOf h' s.sliders.bluffPct) }
        else next
      runBotBefore fuel next

theorem runBot_same_as_before : ∀ (fuel : Nat) (s : Session), s.game.Reachable →
    Session.runBot fuel s = runBotBefore fuel s := by
  intro fuel
  induction fuel with
  | zero => intro s _; rfl
  | succ fuel ih =>
    intro s hs
    unfold Session.runBot runBotBefore
    by_cases hb : s.botToAct = true
    · obtain ⟨next, hm⟩ := Session.botChoice_accepted s hs hb
      have hn : next.game.Reachable := .act _ hs (Session.move_game hm)
      have htrue : (s.move s.botChoice.action).toBool = true := by rw [hm]; rfl
      simp only [hb, Bool.not_true, Bool.false_eq_true, ↓reduceIte, htrue]
      simp only [hm]
      apply ih
      exact ite_game_reachable hn hn
    · simp only [Bool.not_eq_true] at hb
      simp only [hb, Bool.not_false, ↓reduceIte]
```

Test counts: `SessionTests` and the golden `#guard`s (`ReviewTests`, `SliderTests`,
`RiverTests`, all built by `lake build`) pass. `npm test`: 13 files, 217 of 217 tests, before
any change (baseline) and before every commit.

## Examples and bad cases (`Engine/Proofs/Examples.lean`, commit `5a6a30b`)

| Theorem | Every hypothesis met on | Bad output the statement rejects |
|---|---|---|
| `step_keeps_chips` | a hand built by hand (`exHand`, the button calls) | a table with 1,001 chips after the call |
| `illegal_move_rejected` | `exHand`: checking while owing 5 | any new hand after that check |
| (c) `bot_move_accepted` | hand 2 of seed 7 after a fold (reachable; the bot acts first) | a bot that always checks: its check is rejected there |
| (b) `handle_keeps_reachable` | `new_game` from no game, then a fold from that session | `new_game` giving a 1,001-chip session; and a `state` command on a 2,005-chip session, which shows the assumption is needed |
| (a) `handle_error_unchanged` | a real session rejecting a check (`"illegal move"`) | a reply that drops the game, or keeps any other session |
| (d) `viewOf_toCall_le_pot` | `exHand` (call 5, pot 15) and `exShortAllIn` (call 50, pot 350); also applied to the two Risk theorems for the real bot | a "pot" made of earlier rounds only: 0, less than the call of 5 |

Games for (b) and (c) can't be built by hand, because they must be reachable. So those examples
use real games, and `rfl` works out the engine's moves on them. For (a), one hypothesis is not
met by a proof: `Json.parse` returning the JSON of the line `{"cmd":"act","action":"check"}`.
`Json.parse` is a `partial def`, so no proof can work out its result. A `#guard` checks it by
running the code during the build. Every other hypothesis is met by `rfl`.

## Stricter audit (`checks/audit.sh`, commit `f730ca7`)

The audit now also fails on:
- `implemented_by`, `unsafe`, `@[extern ...]` and `debug.skipKernelTC` in the engine's Lean code
  (`--` comment lines are skipped, as for the existing banned words);
- a `maxHeartbeats` line with no comment, either on the line or on the line above.

The current code passes. A self-test (scratch script, not committed) runs these two new checks
on planted files. It flags all six bad cases, and none of the five clean ones. The clean ones
include `unsafeName` as part of a longer name, a commented `maxHeartbeats` line, and a comment
at the end of the file before.

## Checks performed

Before each commit, with the heavy-work mutex `Local\VibeCheckHeavyWork` held for the whole
run. The run also waited until no other `lake.exe` or `lean.exe` build was running.
- `lake build <changed module>`, then a full `lake build` (97 jobs at the end). No warnings in
  this job's files.
- `checks/audit.sh` in Git Bash: it builds `Engine` and `Checks`, finds no banned words, and
  checks the axioms of every name in `comparator.json`. Final axioms:
  - `bot_move_accepted`, `handle_keeps_reachable`, `handle_error_unchanged`: `propext`,
    `Classical.choice`, `Quot.sound`.
  - `viewOf_toCall_le_pot`: `propext`, `Quot.sound`.
  - Not registered: `app_game_reachable`, `Session.botChoice_accepted`: `propext`,
    `Classical.choice`, `Quot.sound`.
- Each new Challenge statement compared word for word with the proved one: all four the same.
- `npm test` in the worktree (`node_modules` linked by a junction): 217 of 217.

Not run here:
- `lake comparator` and `lake check`. They need Linux. The CI workflow runs them on a pull
  request or on a push to `main`. Nothing triggered it for this branch, because no PR was
  opened.
- A fresh-clone test. It was not allowed tonight.

## Unresolved, and notes for merging

- Nothing in (a) to (d) is unproved. There is no counterexample to report.
- Merge conflicts to expect, all append-only: `aarav/river-bot-link` and
  `aarav/review-lost-comparator` also append to the end of `Checks/Challenge.lean`, to
  `comparator.json`'s `theorem_names`, and to `Engine.lean`'s imports. Keep both sides.
  `Challenge.lean` also gets one new import line, `import Engine.Protocol`.
- Job 4 adds a `HandLog` field in `Engine/Session.lean`. This branch changed only the
  `runBot` lines there. If job 4 also edits `runBot`, re-check that
  `Session.runBot_reachable` still builds.
- After the merge, Devom should approve each statement, including whether to register the two
  extras (`app_game_reachable`, `respond_keeps_session_unless_accepted`).

## For the docs

One plain sentence per theorem, for the README trust list, MVP §8/§11 and the pitch:

- `bot_move_accepted`: in every game the engine can reach, the engine accepts every move the
  slider bot picks, whatever its sliders.
- `handle_keeps_reachable`: every command the game program accepts leads to a game the engine
  can reach.
- `app_game_reachable` (proved, awaiting approval to register): the game the app plays is
  always one the engine can reach, so T1 (1,000 chips) and T2 (no card dealt twice) cover the
  real game, not just a model of it.
- `handle_error_unchanged`: a rejected command changes nothing. The program keeps the game
  exactly as it was and shows the same table back.
- `viewOf_toCall_le_pot`: the amount the bot must call is never more than the pot it can win,
  so the "calls only when worth it" and "folds only when not worth it" theorems hold for every
  real decision.
- `docs/proofs-bot-equity.md:35` says "which is always true in a real hand". It can now cite
  `viewOf_toCall_le_pot`.
- The `botMove` fallback in `Session.runBot` is gone. Any doc that says the bot "checks or
  calls if its move is rejected" is out of date. No doc in `docs/` says this today.
