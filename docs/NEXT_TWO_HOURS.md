# Current status and the next two hours

Review date: November 1, 2026. Source baseline: `c11cf65`.
This is a review and an unallocated feature shortlist, not a new MVP specification.

## Where the project stands

The implemented product is beyond the agreed MVP: the Lean game, bot, call/fold river
review, bridge and local UI exist, with practice challenges, Mystery mode, a range viewer,
a Risk explorer, research explanations and a navigable review screen added on top.

- [CI for c11cf65](https://github.com/DevomB/vibe-check-2026-project/actions/runs/41353486059)
  passed: proof audit, Comparator, `lake check`, fresh-checkout app checks and production
  HTTP smoke. Its app job reports **420 tests passed**. `engine/comparator.json` registers
  **69 theorems**. Their scope is described in `PROVED.md` and `GUARANTEES.md`.
- During this review, **58 targeted tests passed** across the review helpers, reference
  grading, practice challenges, result banner and the Lean-backed API demo.
- Port 3000 was stopped. It was restarted from the existing production build and the HTTP
  smoke test passed. Runtime metadata: engine `c0a464d`, server `c11cf65`, exact turn mode.
  The intervening engine changes are proof files, proof imports and Comparator statements.
- UI polish is in a separate worktree, `ui/polish`, with a development server on port
  3017. Its uncommitted changes were left alone. They are not part of this reviewed build.
- The earlier 13-item browser checklist and the two fixed-defect rechecks were on older
  UI builds. They do not certify the latest one-slider and review-screen changes.

The remaining release task is a browser pass on the final merged build, followed by a
timed pitch rehearsal. T10, a separate fast evaluator equivalence theorem, is a stretch
item; the engine currently uses the spec's evaluator directly. It is not an MVP blocker.

## Does the good/bad-move system work?

Yes, within its declared scope. These are the implemented labels, from
`engine/Engine/Review.lean:129` and `src/lib/review.ts:23`:

| Label | Expected value lost against the better of call and fold |
| --- | --- |
| Best | Exactly 0 BB |
| Good | Greater than 0, less than 0.5 BB |
| Inaccuracy | At least 0.5, less than 2 BB |
| Mistake | At least 2, less than 5 BB |
| Blunder | At least 5 BB |

There is no Brilliant, Great or Bad enum. The Lean label uses exact fractions; only the
display rounds. The boundary examples are checked when Lean builds. The review theorems
establish the arithmetic, Best equivalence and label ordering for this model. The UI uses
Lean's label; it does not invent a grade from the actual winner.

The session captures a spot only when the bot makes an opening river bet. It grades the
human's immediate call or fold. Earlier streets, checks, bets, raises and responses to
river raises are ungraded. A review may therefore show every move but have no grades.
This is the main reason the feature can look absent during ordinary play.

The current UI already has badges, grade counts, a move list, arrow-key navigation, board
cards by street, a coaching sentence, call/fold values, equity versus price, range counts,
the Risk explorer, proof links and research summaries. Adding those again is unnecessary.

One display bug found in this pass: `gradedCoach` inferred an exact tie from two rounded
values of 0.00 BB. A small positive value can also round to zero. The follow-up removes
that unsupported equality claim and changes its regression test. The Lean grade is unchanged.
The follow-up's 15 review-helper tests and TypeScript check passed.

## What a review from the player's perspective still needs

The existing model already uses the human's cards, board, amount to call, remaining stack,
unmatched-bet adjustment and the selected bot's river betting set. It does not use the bot's
actual hole cards. Its missing context is more specific:

1. **Earlier betting does not update the range.** Every compatible hand in the bot's river
   betting set receives equal weight, even if earlier actions would make that hand unlikely
   or impossible. Exact arithmetic for that set is not an exact posterior for the full hand.
2. **Best compares call and fold only.** It does not establish that raising would be worse.
3. **The human is judged by chip EV.** The bot's Risk sets its strategy, not the human's
   utility. No player risk preference, bankroll model or survival objective is used.
4. **Mystery adds uncertainty about the opponent.** After reveal, grades use the bot's real
   setting. The UI discloses this. They do not measure the quality of the player's decision
   under whatever belief about the hidden setting the player held at the time.
5. **Grade cutoffs are a product choice.** The 0.5/2/5 BB bands are published and consistent,
   but are not research-established boundaries or adjusted for learner skill or stack depth.

For a fuller decision model, evaluate each supported action using information available at
the decision, a declared opponent-hand distribution and an explicit continuation policy.
Subtract the chosen action's value from the best supported action's value. Earlier streets
and raises need future betting responses as well as card equity. Equity alone cannot grade
them correctly.

## The two additions worth trying

These are proposals. This review does not implement them. Estimates are rough and assume
reuse of the current Lean grader and UI; stop adding features with 40 minutes left.

### 1. Human decision sensitivity: same bet, different assumed opponent

Aim for a compact table at an already graded river decision:

| Assumed opponent | Your call EV | Your fold EV | Better supported choice |
| --- | --- | --- | --- |
| Risk 0 | From Lean | 0 BB | From Lean |
| Risk 50 | From Lean | 0 BB | From Lean |
| Risk 100 | From Lean | 0 BB | From Lean |

This answers the player's question directly: how does the decision change when the
opponent's river betting range changes? The existing Risk explorer asks how the **bot's**
move changes; this would ask how **your call/fold evaluation** changes.

Reuse `Sliders.ofRisk`, `reviewRiver`/`gradeRiver` and the ranked-hand helpers already in
`Engine/Explain.lean`. Keep all grading in Lean. Start with three presets, not 101 points.
Budget roughly 45-60 minutes, including API and renderer checks; benchmark the added review
latency before keeping it. New UI/JSON wiring remains tested, not newly proved.

Acceptance:

- Preserve hero cards, board and price. Change only the assumed range rule.
- Say "Same river bet, different assumed opponent". These are conditional scenarios, not
  claims that a replayed full hand would reach the same state.
- The actual-setting row must match the existing review, before display rounding.
- Do not inspect the bot's actual cards or advance the session.
- Use the existing Mystery reveal gate and Peek warning.
- Retain the uniform-range/earlier-betting limitation and call/fold-only scope.
- Test at least two fixtures whose call EV differs across the assumed opponent settings.

If it takes longer than an hour, ship the existing review and choose the smaller feature.

### 2. Blind practice using the three validated spots

Randomly choose an existing challenge. Before the decision, show neutral wording such as
"River decision 1"; reveal "Catch a bluff" or "Avoid a bad call" only after the choice.
Keep the expected answer, grade and outcome hidden until then. Reuse the existing challenge
loader and Lean review. Budget roughly 20-35 minutes.

Acceptance:

- No title or prompt gives the answer away before the action.
- Only Lean determines the grade. The stored expected result remains a test fixture.
- Count correct decisions as "2 of 3 practice decisions", not whole-game accuracy.
- Retrying a mistake reaches the identical spot and preserves call/fold values.
- Check all three spots, both choices, and the case where a Best call still loses.

Reserve the remaining 30-40 minutes for merge conflicts, checks, a fresh browser pass and
the pitch. The UI polish already underway should supply the visual changes.

## Research backing and its limits

One smaller addition, roughly 10-20 minutes: make the existing "Why?" citations clickable.
`WhyChip.tsx` currently displays source names and IDs, then points to a repository folder;
`Citation` has no URL field. Add verified primary-source URLs to the data and ordinary links
to the panel. This makes the research backing inspectable during the demo. If time is tight,
choose this instead of blind practice; keep it separate from the proof links.

- **Poker decision context:** [DeepStack, Moravcik et al. (2017)](https://arxiv.org/html/1701.01724v3)
  describes values in imperfect-information games as depending on player ranges and the
  public state. This supports treating the range assumption as part of the review, not
  claiming that raw showdown equity solves an earlier-street decision.
- **Unknown opponent:** [Bayes' Bluff, Southey et al. (UAI 2005)](https://arxiv.org/abs/1207.1411)
  models beliefs over opponent strategies and responses to those beliefs. A genuine
  player-perspective Mystery grade would require such a declared belief model. The proposed
  three-setting panel is sensitivity analysis, not a Bayesian inference engine.
- **EV-loss review UX:** [GTO Wizard's Analyzer documentation](https://help.gtowizard.com/how-to-use-the-hand-history-analyzer/)
  reports losses in BB, replays decisions and handles missing solver spots explicitly. This
  supports displaying supported coverage and EV loss; it does not validate our range or bands.
- **Brilliant/Great:** [Chess.com's classification documentation](https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-etc)
  uses additional chess-specific rules and learner context. Those labels cannot be imported
  as scientific poker categories. A poker version would need its own declared definition.
- **Luck versus skill:** [AIVAT, Burch et al.](https://arxiv.org/abs/1612.06915)
  evaluates performance with variance reduction using known strategies and value estimates.
  It does not justify calling actual winnings minus this partial river grade "luck".

Defer a full-street solver, history-conditioned ranges, automatic opponent learning,
personal risk utility, whole-game accuracy and a claimed skill/luck decomposition. Each
requires additional modeling and validation, rather than just a new label or chart.

## Names

- **Proof of Bluff** — memorable for the hackathon; connects poker and verification.
- **Pocket Lemma** — distinctive mathematical identity with a poker reference.
- **Read the River** — immediately suggests learning and the current review scope.
- **Riverwise** — approachable consumer name.
- **Callibre** — a call/judgment pun, suited to a training product.
- **Show Your Odds** — descriptive and easy to explain.

My hackathon choice: **Proof of Bluff**. Tagline: **Play the hand. Check the reasoning.**
These are brainstorming candidates, not claims of name or domain availability.

## Final browser pass before leaving

Use the final production URL and hard-refresh. Record its server and engine commits.

1. Practice bad call: Mistake, -2.67 BB; retry Fold: Best.
2. Practice right-and-lose: Best, +10.32 BB despite losing.
3. Catch a bluff: Best, +1.57 BB; Peek re-hides cards but its review warning persists.
4. Review: select every move, navigate with arrows/Home/End, verify board cards and grade
   badges; confirm ungraded moves are labeled as such and proof links return intact.
5. One-slider Risk test from the updated quickstart: Fold at 0-35, Call at 36-100 for that
   fixed bot decision. Do not use the old two-slider expectation.
6. Next Hand, short-stack/all-in payout, all Game Over buttons, New game and seed replay.
7. Mystery: no setting/reason/range leaks before the guess, one reveal, clear retrospective
   grading assumption afterward.
8. If new features ship, check their acceptance items above on the final merged build.
9. Rehearse the pitch once with a timer. Explain one proof, one bad call and one good call
   that loses. Keep the full-hand strategy limitation in the Q&A.
