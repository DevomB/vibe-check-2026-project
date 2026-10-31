# MVP review and decision log

Reviewed October 31, 2026, starting at 1:57 PM Pacific, against MVP v2
(`5f6c16beffc4f3bff6dfbd0efb32c92df5a8cc2c`). Confirmed decisions have been
folded into MVP v3 and the README. Application source was left untouched.

These are 36 findings: concrete errors, missing contracts, and delivery risks.
They are not 36 implementation bugs. A clarified requirement still needs its
implementation and checks before it is complete.

## Decisions confirmed

- TypeScript is a rapid prototype. Lean remains the shipping game engine.
- No personal task allocations. Track completed work and remaining work instead.
- Review means best among call/fold, for responses to opening river bets;
  raises remain ungraded.
- Risk uses the actual win/tie/loss chip outcomes and loss-weighted utility.
- Bluff targets the designated bluff share of a defined hand set, not an
  exact observed frequency among played bets.
- Rank candidate hands by showdown score, then fixed card order for ties.
- Detailed bot reasons appear after the hand; live messages remain generic.
- Bet/raise amounts are street totals throughout the engine, JSON and UI.
- An explicit Next Hand action holds results for review; hand-over and
  game-over are separate states.
- Choose a fixed exact-or-Monte-Carlo turn mode from a compiled benchmark.
  River stays exact.
- Value count uses floor(30%); bluff count rounds its formula half upward.
- Opening bets use legal pot sizing; raises are clamped to legal bounds,
  and an unavailable raise falls through to the call/fold utility rule.
- Tier 1 remains mandatory before stretch work; optional proof claims enter
  the pitch only when their own proofs/checks have passed.
- Lean v4.35.0, matching dependencies and the three standard axioms only;
  no `native_decide` in shipped proofs.
- Lean advances bots/streets until the next human decision or hand end.
- The required demo is one local active game; public hosting and concurrent
  games are outside scope.
- The TypeScript/Next.js prototype and its Makefile were published during
  this review in commit `69c4e46`. The done/remaining lists reflect that.
- The user said all teammates are available for the remaining hours. The
  stated Sunday 4:30 PM deadline remains the planning assumption.

## Scope, time and development flow

**01. The available time is shorter than 36 hours.** At the start of this
review, Sunday November 1 at 4:30 PM Pacific was about 27.5 hours away,
including the overnight clock change. The research synthesis budgets
4 people times 34 hours, which is not this remaining budget. Availability
has been clarified; planning and checkpoint scope still need to fit the
actual deadline. Source: MVP sections 12 and 15; SYNTHESIS section 3.

**02. The prototype-to-Lean transition has no acceptance gate.** The current
UI imports and runs the TypeScript engine and bot directly. Saying Lean
comes later does not establish when the real bridge works. The first
integration check should run a real Lean request from the UI, followed by
one complete hand. Decide the cutoff for replacing prototype logic before
building more features against it. Source: MVP section 7; `src/hooks/useGame.ts`.

**03. Personal allocations were premature. Resolved.** The MVP and README
assigned people to work before the team had agreed its workflow. They now
contain done/remaining lists, with no personal allocations. Remaining work
includes bot implementation, review implementation and shared interfaces,
without implying anyone has accepted an assignment. Source: MVP section 11.

**04. Research contains conflicting instructions and unsupported status
claims.** SYNTHESIS says never to use Monte Carlo, proposes a different risk
utility and three sliders, refers to a working Python bridge, and marks a
`KuhnPoker/` implementation done. No such Lean project was found in this
checkout during the review. OPEN_QUESTIONS says the toolchain is already
pinned; no project pin was found. Treat these as research notes requiring
correction, not completed project work. The MVP now states its precedence;
the research files themselves were left untouched.

## Bot and review mathematics

**05. The original Risk formula mishandles ties. Resolved in the spec.** It
uses equity as though every tie were half a win and half a loss even after
losses receive extra weight. On a board where everyone must tie, P=200,
C=100 and Risk=100 produced -50 in the old test, although calling guarantees
a 50-chip gain. The new formula uses win/tie/loss counts and actual payoffs.
The implementation and preflop data must preserve those separate counts.
Source: MVP sections 3 and 5.

**06. Risk monotonicity was described too broadly. Resolved in wording.**
The theorem compares the same decision state, outcome counts and other
settings. It does not compare whole games that take different actions or
consume different random samples. Also, the specified opening bets and
75%-equity raises are independent of Risk; Risk is not a general aggression
slider. Source: MVP sections 3, 5 and T4.

**07. River branch precedence and ranking were underspecified. Resolved
in the spec.** River hand-set betting now applies when no bet is faced; the
facing-bet rule still applies otherwise. Hand ranking uses showdown score
and fixed card order, not nested equity computations. The user also confirmed
legal pot sizing and fallback. Card-order selection ties never break actual
showdown ties. Source: MVP section 5.

**08. Whole-hand rounding and the meaning of a bluff needed precision.
Resolved in the spec.**
There are 1,081 two-card candidates on a five-card board. Thirty percent
is 324.3 hands. The user selected floor for the value count V, then nearest
integer, halves upward, for `V * b / (100-b)`. Select disjoint sets with the
same tie order in the bot and review. On a board where everyone ties,
the designated bluff hands are not actually weaker: the promise is about
strategy labels, not a universally losing hand class. Source: MVP section 5.

**09. Exact played-bet Bluff frequency is not guaranteed. Resolved in the
spec.** A hand-set count does not fix the frequency among dealt hands or
hands reaching the river. Card removal and earlier actions change the
population, and finite samples vary. T7 now counts the bot's defined
board-only hand set. The review must filter human blockers from that SAME
set, not rerank and rebuild it after seeing the human's cards.

**10. “33% is balanced” needed qualifications. Resolved in wording.** One
third is the familiar reference for an idealized pot-sized, polarized
call/fold decision. The bot's strongest 30% are not guaranteed pure value
against every caller, and stack caps can change the bet/pot ratio. Integer
33% is also an approximation of one third. The MVP no longer presents
this as a balanced Hold'em strategy. Source: MVP section 3; research A03.

**11. “Best” included actions the review does not evaluate. Resolved.**
T5 and review wording now compare call/fold only. Human raises and responses
to bot raises remain ungraded. The UI must display that limited comparison,
rather than imply the best unrestricted poker action. Source: MVP sections 6 and 8.

**12. Exact calculation is not an exact conditional opponent model.**
The MVP deliberately ignores earlier betting. Equal weighting of the
remaining river betting combinations is therefore a board-only range
model, not generally the true conditional distribution given the hand's
history. The wording now discloses this. Prove calculations against that
declared model; avoid promising exact actual-opponent EV. Source: MVP section 6.

**13. Live reasons could invalidate the review's information assumptions.
Resolved.** “Bluff,” “value,” or hand-dependent equity reveals information
the proposed range calculation ignores. Detailed reasons now appear only
after the hand. The review still needs a saved view from BEFORE the human
acted; computing it after the hand must not admit later cards or outcomes.
Source: MVP sections 2, 6, 8 and 13.

## Betting rules and equity computation

**14. Raise amounts had no shared units. Resolved.** `amount=120`
could mean a street total, additional chips paid, or an increment above
the opponent. UI bounds, JSON and engine types must use one convention.
The prototype already uses street-total `to` values. The user selected
street totals, now specified across the engine, JSON and UI.
Source: MVP sections 4, 5 and 13.

**15. “Raise to pot” and legal fallback were missing contracts. Resolved
in the spec.** If the pot
before the opponent's bet is 100 and they bet 50, the pot at your decision
is 150. A pot-sized raise, with zero already in on that street, is TO 250:
call 50, then raise by the 200 pot after calling. Define the target relative
to the player's existing street contribution. Also define the river opening
bet size, clipping to the stack, the minimum full raise, short all-ins, and
what the 75%-equity branch does when raising is unavailable. A strong bot
must not return an illegal raise. The user confirmed these pot sizes and
clamping, with the call/fold utility rule used when raising is unavailable.
Source: MVP sections 4 and 5.

**16. Short calls require a contestable pot, not the entire overbet.**
With a 100 pot, an opponent overbet of 900 and only 100 available to call,
800 is uncallable excess. Using P=1,000 gives incorrect pot odds; the
contestable P is 200 before the call. Refund excess and count only chips
the caller can win. The spec now states this requirement; it still needs
implementation and checks. Source: MVP sections 4, 5 and T1.

**17. Heads-up still has essential all-in edge cases.** Deferring multiway
side pots does not defer unmatched-bet refunds, a stack below a blind,
automatic board runout, disabling raises against an all-in player, button
rotation, or transferring and clearing the pot exactly once. Define these
cases in the rules/state transition contract. A short all-in must not reset
the last full raise size. The applicable baseline is the
[official Poker TDA rules](https://www.pokertda.com/view-poker-tda-rules/),
especially the heads-up and full-raise/reopening rules.

**18. Exact turn equity omitted the unknown river. Fixed in the spec;
mode-selection process agreed.** For known bot cards and four board cards,
`C(46,2) * 44 = 45,540` opponent-hand/river outcomes must be considered.
River equity has 990 opponent combinations. Sampling a single river is
not exact turn equity. Benchmark compiled Lean and agree a reproducible
exact-or-sampled mode rather than letting machine speed silently change
the replay. The user selected a fixed mode chosen from a compiled benchmark;
the benchmark and mode choice remain work to do. Source: MVP sections 5 and T6.

**19. The preflop table is a missing deliverable, and equity alone is
insufficient for the corrected utility.** The 169 entries need win, tie
and loss counts, not just one equity percentage. Specify their key order,
seed, sample count, generator command and fallback if absent. A hand-coded
float table would contradict the stated counts-only design. Source: MVP sections 5 and 7.

**20. A seed alone does not define a replay.** Specify the PRNG algorithm,
shuffle/deal order, initial button, action log, slider settings, data version
and how Monte Carlo draws are derived. Sharing one mutable RNG between
equity sampling and dealing makes a changed sample count change later
cards. Keep the shuffle sequence stable when sampling implementation
changes. Risk comparisons must reuse the same outcome data. Source: MVP sections 4 and 5.

## Engine/web contract

**21. The protocol could not explicitly advance a hand. Resolved in the spec.**
It has `new_game`, `act` and `review`, but no next-hand action. `over` does
not distinguish a completed hand from a completed match. Agree when result
and review remain visible, how the next hand starts, and what happens on
refresh. The user selected explicit Next Hand with separate hand/game status.
`next_hand` and `playing`/`hand_over`/`game_over` are now in the protocol;
refresh/session recovery still needs a minimal rule. Source: MVP section 13.

**22. Bot scheduling was undefined. Resolved; process details remain.** Does one human
request run all subsequent bot actions until the next human turn or hand
end? What does the UI display while Lean computes? Keep one coherent
request/response order and prevent duplicate actions while pending. Define
the minimal local-session behavior, child-process failure and restart.
Stdout must contain newline-delimited JSON only; diagnostics belong on
stderr. The user selected Lean-driven progression to the next human decision
or hand end and one local active game. Restart/error handling still needs
a small explicit contract. Source: MVP sections 7 and 13.

**23. Review needs durable decision snapshots.** `review(hand=3)` requires
an archive of the human cards, board, pot, call cost, action, settings and
range-model inputs at each eligible decision. Saving only final state or
the bot's actual hand is insufficient. Define review-before-hand-end
behavior, empty/ungraded hands, and whether detailed post-hand reasons are
part of that response. Source: MVP sections 6 and 13; T8.

**24. Input types and failure behavior need a boundary contract.** Define
seed width/range, integer slider values and defaults, positive integer
amounts, unknown commands, malformed JSON, actions outside a live turn,
and invalid hand references. Rejection must not change game state or
consume the shuffle RNG. All chip amounts and bounds must share the
selected units. Source: MVP sections 1, 7, 13 and T3.

## Proof, build and test acceptance

**25. The proof dependencies do not yet support the headline promise.**
T5 can prove correct labels for supplied EVs while those EVs are computed
from a faulty evaluator or enumeration. T6 is optional and evaluator
equivalence is stretch. T7/T8 are also optional although the original pitch
promised them. The user confirmed Tier 1 as mandatory, with optional properties
advertised as proven only when actually checked. Correct-EV coverage still
needs evidence; a label theorem alone does not prove it. A small end-to-end verified feature
is more useful than several disconnected formula proofs. Source: MVP sections 8 and 14.

**26. Each theorem needs its real invariant and acceptance examples.**
T1 needs valid initial states and a pot definition that includes committed
chips exactly once, including settlement. T2 needs the deal path to consume
cards without reuse, not just a shuffle permutation. T3 needs a reviewed
legality specification, not only “the bot passes its own checker.” T5 needs
the zero-loss case and explicit interval boundaries. Keep the named
concrete valid and known-bad examples required by the MVP. Source: MVP section 8.

**27. The final checker platform was wrong. Corrected; setup still needed.**
The original timeline allowed “Linux or Mac.” The sandboxed checker needs
Linux; WSL is the Windows route to validate. A native Mac laptop alone is
not that environment. Lean's [4.35 release notes](https://lean-lang.org/doc/reference/latest/releases/v4.35.0/)
confirm the checkers and Linux sandbox. Pin the project version and
dependencies and run a tiny real check early. No project toolchain pin
was present when reviewed. The user has now selected v4.35.0 with matching
dependencies; the project pin and actual checker run remain to be delivered.
Source: MVP sections 1, 12 and 15.

**28. Axiom, challenge and spec-change policy need an executable gate.**
The user selected only `propext`, `Classical.choice` and `Quot.sound`, with
no `native_decide` in shipped proofs. A challenge file containing intentionally unproved statements
must not leak `sorryAx` into the shipped proof targets. Human review must
cover definitions a theorem depends on, not merely its surface text.
Use the actual challenge/solution checks described in the
[Lake documentation](https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Lake/).
The default build/check targets must include every shipped proof module.
Source: MVP section 8; CLAUDE.md.

**29. Prototype Makefile success would not establish final-app readiness.**
The local Makefile currently invokes npm only. The final entry point must
build and launch Lean as well, resolve the final root/src/web layout, and
work in the stated target environment. Installing `make` alone does not
install the shell or other tools a recipe may assume. Pick a supported
fresh-clone test environment and actually exercise it. Source: MVP sections 1 and 7.

**30. The external-oracle claim is not reproducible from the handoff.**
The MVP reports 48/48 checks for `poker-calculations@4.0.3`, but this review
did not find the corresponding runnable harness, seed, cases and result
artifact in the shared project. That does not establish the claim is false;
it means teammates cannot replay it from these files. Retain the exact pin
and obtain the check command and evidence. “Every equity number wrong” for
older releases is also stronger than showing an evaluator bug exists.
The MVP now marks the old result as reported and still needing replayable
evidence, and avoids claiming every older-version result must be wrong.
Source: MVP section 7.

**31. The test workload needs a measured time budget.** Exact flop equity
against a random opponent has `C(47,2)*C(45,2) = 1,070,190` outcomes per
spot. One hundred thousand rank checks are a separate workload. Time the
compiled Lean code before committing to counts. Seed Monte Carlo tests;
define the variance/bounds with ties and an acceptable failure policy.
A four-standard-error condition is statistical evidence, not a theorem
or an absolute guarantee that every randomized test run passes.

## Demo and document consistency

**32. A fixed-blind match has no deterministic finish time.** Individual
hands ending does not bound an entire match: repeated split pots or other
cycles can continue. The demo needs known seeds/action sequences, a
reviewable hand and a reset path. At 60% Bluff, a normal bluff-catching
call may be profitable, so the pitch must not assume any arbitrary call
will grade Blunder. Verify the five-minute presentation allowance too.
Source: MVP sections 4, 12 and 14.

**33. The original pitch exceeded the guarantees. Partly resolved.**
No duplicate cards is not uniform-shuffle fairness. The one-decision Risk
theorem is not a whole-game hand-count theorem, and T7 is not a realized
bet-frequency guarantee. The Kuhn stretch now says unexploitable instead
of unbeatable. Those claims are corrected. The final pitch
must still omit any property whose actual Lean proof/check has not passed.
Source: MVP sections 8, 9 and 14.

**34. Checkpoint B allowed holes while also unlocking stretches. Gate
resolved in the spec; execution still needed.**
It permits Tier 1 proofs to remain as a list of `sorry`s, while the stretch
ladder opens after that checkpoint. A feature freeze at noon is too late
to discover that the first Comparator run cannot start. Choose a gate
based on the working verified core, and a cutoff for reducing scope if it
is not ready. The user confirmed Tier 1 is mandatory before stretch work.
Do not use elapsed checkpoint time as evidence of completion.
Source: MVP sections 9, 10 and 12.

**35. The README referenced v1 section numbers and stale research status.
Corrected.** Work status is now section 11, messages section 13, pending
decisions section 15 and deferrals section 9. Named assignments are gone,
the published synthesis is linked, and the prototype's tests are identified
as tests rather than Lean proof evidence. Research's stale implementation
claims remain a separate issue (04).

**36. The JSON examples had inconsistent pot/bet and grade values. Corrected.**
The old turn response had pot=60 and an outstanding bet/call of 60,
leaving no earlier pot. The updated example has pot=120, stacks 470 and
410, and call=60. It can follow both players contributing 30 preflop,
checking the flop, then the bot betting 60 on the turn. It preserves
1,000 chips and no longer exposes exact bot equity during play. The review
example also called a 4.1-big-blind loss Blunder despite the 5-big-blind
Blunder cutoff; its label is now Mistake.

## Remaining question queue

These need technical definitions or evidence rather than personal task allocations:

1. What measured response-time budget determines the fixed turn mode, and
   what fixed sample count is used if it is Monte Carlo?
2. Which PRNG/shuffle/deal rules and replay metadata are frozen? How are
   equity draws kept from changing the shuffle sequence?
3. Where are the 169 preflop count records and their reproducible generator?
   Where is the runnable harness behind the reported 48 oracle checks?
4. What are the remaining state/response types, stored review snapshots,
   post-hand reason fields, JSON error behavior and refresh/restart policy?
5. Which fresh-clone environment and final frontend/engine paths will the
   Makefile support and demonstrate?
6. Which proofs and checks actually establish the EV calculation, rather
   than only the mapping from supplied EVs to labels?
7. What exact seed/action sequences make the demo short and reproducible,
   and has the five-minute presentation slot been confirmed?

The next implementation milestone is an actual browser-to-Lean hand,
followed by the slider bot and review. No personal assignments are implied.

## Checks performed

- Read the complete MVP, README, organizer rules, research synthesis/open
  questions, checker guidance, and the relevant local engine/UI call path.
- Ran the TypeScript prototype suite: 70 tests across 5 files passed at
  2:08 PM Pacific. This did not run or verify a Lean engine.
- Ran exact Python/Fraction calculations for the Risk thresholds and tie
  counterexample, enumeration counts and corrected state accounting. Also
  compared the corrected integer Risk inequality with exact expected utility
  in 9,920 cases; all matched, including neutral-risk pot odds.
- Checked the official Lean and Poker TDA documentation linked above.
- Did not modify application code or the active research documents.

The core arithmetic can be replayed with Python's standard library:

```python
from fractions import Fraction as F
from itertools import product
from math import comb

for risk, threshold in [(0, F(1, 3)), (50, F(1, 2)), (100, F(3, 5))]:
    weight = F(100 + 2 * risk, 100)
    assert weight / (2 + weight) == threshold

assert F(1, 2) * 200 - 3 * F(1, 2) * 100 == -50  # old surrogate
assert (200 - 100) // 2 == 50                      # guaranteed tie gain
assert comb(45, 2) == 990
assert comb(46, 2) * 44 == 45_540
assert comb(47, 2) * comb(45, 2) == 1_070_190
assert 470 + 410 + 120 == 1_000

for w, ties, losses in product(range(5), repeat=3):
    if w + ties + losses == 0:
        continue
    for call in range(1, 5):
        for pot in range(call, call + 5):
            for risk in [0, 1, 50, 100]:
                utility = w*pot + ties*F(pot-call, 2) - F(100+2*risk, 100)*losses*call
                lhs = 100*(2*w*pot + ties*(pot-call))
                rhs = 2*(100+2*risk)*losses*call
                assert (lhs >= rhs) == (utility >= 0)

v = 30 * 1081 // 100
for pct in range(61):
    divisor = 100 - pct
    b = (2*v*pct + divisor) // (2*divisor)
    assert 0 <= b <= 1081 - v
    assert abs(F(b) - F(v*pct, divisor)) <= F(1, 2)
```
