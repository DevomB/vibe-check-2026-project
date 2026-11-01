# Integrated MVP review — November 1, 2026

The required product is implemented, with substantial additions beyond the MVP. The
remaining release gate is a visual rehearsal on the demo machine. Passing engine proofs,
API checks and a fresh Linux launch does not establish that every browser interaction works.

## What was integrated

| Work | Branch tip reviewed | Result |
| --- | --- | --- |
| Web hardening | `65b16f9` | Offline fonts/build, engine-loss recovery, pot/Fold fixes, replay identity, Peek, test enforcement |
| Session proofs | `b1dadf0` | Accepted bot moves, preserved reachability, unchanged rejected commands, pot/call inequality, examples, stricter audit |
| Demo/release | `c622d46` | Reproducible scenes/challenges, API regression, demo checklist, pitch and claim table |
| Review insights | `e333659` | Lean range counts and Risk explorer, UI panels, integration tests and calculation proofs |
| Modes/proofs | `809d138` | Proofs drawer, practice challenges, server-private Mystery settings and reveal |
| Aarav | Already on main at `c8ea04c` | River ordering/bot-set connection, review examples, differential rerun and T9 |
| Cloud fuzz | `8f5c751` | Preserved the harness and its historical results; it did not test the five newer branches |

The original branch reports are historical observations. A report saying a branch was
unmerged is not a current status claim. Git ancestry and the integrated checks are the evidence.

## Actual integration fixes

1. Preserved both sides of the theorem registry/import conflicts. No existing theorem entry
   was dropped. The registry now has **46 theorem targets**.
2. Adapted the session/protocol proofs to the new Peek flag and compiled build identity.
   `handle_error_unchanged` now covers every valid Peek setting and every identity string.
   Its JSON response is the requested view of the unchanged session. Invalid Peek values
   are rejected before game-command handling. This changes the serialization contract,
   not the promise that rejected requests preserve the game.
3. Generalized app reachability to the actual `respond ... commit` path used by Main.
   Registered `app_game_reachable` and `respond_keeps_session_unless_accepted`.
4. Registered `exploreHand_moves`, `exploreHand_risk_monotone`, `rangeOf_adds_up` and
   `rangeOf_counts`, rather than advertising unregistered panel proofs.
5. Preserved the logged bot inputs while removing the proved-unused fallback. Preserved
   both the insight and Mystery protocol extensions and their ReviewModal contract.
6. Updated the demo regression to allow the new range field while still checking all
   original verdict values. Made this newer suite fail when the engine is missing too.
7. Updated stale Proofs-drawer references/limits after the session and river proofs landed.
8. Added a production HTTP smoke check and a fresh-Linux-checkout app job to the existing
   CI workflow. It runs the required Makefile entry points, not only an imported handler.
9. Limited Next build workers to two to bound memory on the shared laptop. No dependency,
   game-rule change, new evaluator or speculative refactor was added.

## MVP cross-reference

| Requirement | Status and boundary |
| --- | --- |
| Two-player 500/500-chip, 5/10-blind game | Implemented, exercised by engine/API tests; chip conservation and reachable game invariants checked |
| Street-total bets/raises, short all-ins, payouts, Next Hand/game over | Implemented; engine and route checks cover these paths |
| Lean decides all game actions and review grades | Implemented; UI value imports from the TS prototype were removed |
| Risk actual-outcome utility | Implemented and proved; includes ties, legal-raise override and fallback to call/fold |
| Bluff hand-set target and ranking/rounding | Implemented and proved; it is not an observed betting-frequency guarantee |
| Preflop/flop/turn/river equity modes | Fixed table / 1,000 samples / exact / exact. Preflop and flop remain estimates |
| Opening-river-bet call/fold review | Implemented; raises and earlier streets deliberately remain ungraded |
| No hindsight, reasons only after the hand | Implemented and checked; Peek is an explicit aid with a review warning |
| Replays and private random seeds | Implemented; game-over metadata identifies mode/build/server, normal random seeds stay private until game over |
| Tier 1 T1–T5 and Tier 2 T6–T8 | Present and checked, with additional session/app integration statements |
| T9 hand termination | Beyond the mandatory MVP: accepted runs of one hand have at most 200 moves. This is not a bound on an entire match |
| T10 fast-evaluator equivalence | Optional and presently inapplicable: there is no distinct fast evaluator; play uses the specification's `bestScore` |
| One local active game and required launch command | Supported; fresh Linux checkout/install/launch and real HTTP checks passed |
| Final browser demo and pitch rehearsal | Still requires a human click-through and timed pitch on the intended machine |

Beyond the MVP: Peek, Proofs drawer (S1), Mystery opponents (S9), practice challenges,
the range viewer and Risk explorer. No additional features are required for acceptance.

## Validation evidence

- Integrated native Lean build: **109 jobs passed**.
- Integrated unit/native/API suites: **296 tests in 19 files passed**, with no skips.
- Production Next build: passed with TypeScript checking and the normal Turbopack builder.
  The isolated worktree needed a physical copy of existing dependencies: Turbopack rejected
  a junction pointing outside the checkout. A standard install does not have this issue.
- Production HTTP smoke: passed lobby, illegal action handling, Peek on/off,
  a graded river review, range totals, the 101-action Risk explorer, game-over seed reveal,
  deferred Mystery reviews and an eligible one-time reveal.
- Fresh Linux CI at implementation commit `4142d29`: **both jobs passed** — build/axiom
  audit/Comparator/kernel re-check, and fresh checkout `make install`, typecheck/tests,
  `make run PORT=3001`, followed by the production HTTP smoke.
  [CI run 41336322319](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41336322319).
- Historical cloud stress: 2,232 games, 64,573 hands, 257,876 requests and 0 failures on
  `df6904a`; the report was removed later, so read it with
  `git show 3f7c4e2:tasks/reports/cloud-fuzz.md`. Do not attribute those counts to this merge.
- The recorded differential run passed all 11 groups, including 100,000 random and 6,000
  edge-case ranking deals. It was rerun by Aarav; this integration did not rerun the full
  differential campaign.
- Integrated native fuzz: **17 games, 548 hands, 2,243 requests, 189 deliberately bad
  requests, 3 matching replays and 0 failures**. The two-minute budget completed 17 of
  the requested 40 games; there were no hand-cap stops or slow replies. This was CLI
  coverage, not a browser test. See `validation/integration-fuzz.json`.
- All six recorded fixtures passed on the integrated native program: three practice
  challenges and demo scenes a/b/c. The checked binary's SHA-256 was
  `95a6b0d65a29fd9070b06cd9f5c65592e47e660bc3a45142cb86864c9d0ceb3f`.
- Visual browser verification: **not completed**. The computer-use service blocked native
  browser control because it could not confidently determine the current URL. No browser
  screenshots or interactive pass are claimed.

## What still needs doing, in priority order

### Release checks — do before presenting

1. Run the click-through in `DEMO.md` on the demo machine: normal hand, fold, showdown,
   short stack/all-in, graded/ungraded review, Next Hand, replay, Peek on/off, engine loss,
   both insight panels, Proofs drawer, all three challenges, Mystery guess/reveal.
2. Check visibility and focus when opening nested dialogs, and that the card/board/review
   animations finish before the next scene. These are browser checks, not established by
   server rendering or route tests.
3. Time the five-minute pitch. Use the prepared scenes and a backup recording. Recheck
   response times on the final machine with idle hardware; overnight timing is not a
   performance guarantee.
4. Preserve the final seed, sliders, ordered human actions, exact turn mode and compiled
   engine identity. The fresh Linux launch is checked; an offline native Windows Makefile
   launch has not been established. Use the documented supported shell or PowerShell path.

### Product choices / small refinements — do not block the core MVP

- **Structural debt:** Tectonix quality_signal rose from 6,930 to 6,944 and cycles stayed
  at zero, but its coupling measure rose from 0.09 to 0.32 and complex-function count
  from 18 to 23. Its session gate therefore failed those structural thresholds. These
  are triage signals, not correctness failures. The larger mode/review flows in the hook
  and route deserve later simplification; this integration intentionally avoids a refactor.

- **Stale tabs:** no game/session ID protects one browser tab from replacing or acting on
  another tab's game. Use one active tab in the demo. Add IDs before multi-session use.
- **Refresh/resume:** refresh returns the UI to setup; it does not reconstruct the prior UI
  from the still-running engine. Persistence is outside the chosen one-local-game scope.
- **Mystery + Peek:** intentionally allowed. It reveals cards, not settings, and makes the
  guessing exercise easier. A stricter challenge mode could disable Peek; that is a product
  decision, not a privacy defect in the settings redaction.
- **Practice:** the teaching prompt asks for call/fold, but the normal table can offer raises.
  A raise can remain ungraded. A dedicated two-answer practice UI would be clearer.
- **Proof drawer:** still organized around T1–T8. T9 and the panel integration theorems can
  be made more visible; their absence from the drawer does not remove their proofs.
- **Replay UX:** full export/import of the move sequence would be useful. Seed-only replay
  reproduces cards; the same human actions are needed to reproduce the decision trajectory.
- **Long sessions:** engine hand logs grow over a match. Add a retention policy if using this
  for long-running training; the intended short local demo does not exercise that ceiling.
- **Makefile ergonomics:** port occupancy is checked after the build, and native Windows
  PATH conventions differ. Neither justifies changing the game implementation now.

### Remaining proof boundaries — disclose, not disguise

- Node, React, browser rendering, secrecy/redaction and transport correctness are tested,
  not formally verified. Conditional protocol invariants do not prove JSON parser accuracy
  or every serialized field's correctness.
- `legalOptions` is proved equal to `Legal` (`legalOptions_exact`, ccba65c); the browser's
  rendering of it and the displayed raise bounds are tested, not proved, and the engine still
  rejects illegal actions it receives.
- Explorer calculations match the bot on recorded inputs. Faithful capture of those
  original inputs is tested, not proved.
- The board-only review range ignores earlier betting. Its EVs are exact for that model,
  not a claim to have solved conditional Hold'em strategy or to grade raises.
- Preflop data, flop sampling, the Lean compiler/runtime, standard axioms and parallel
  task execution remain the disclosed trusted surface.
- S2 (faithful bot-reason text), S3–S8 and S10 are not promised by this integration. No
  adaptive opponent, multiplayer, side pots or earlier-street grading is required.

The integration implements/fixes the items above the validation section. The refinement
lists are recommendations for later work, not claims that more features are being built.
