# Lane 2 contract inventory: every web, test and demo-record file the one-slider protocol touches

Written Sun Nov 1, 11:50, by the helper session, against the `sunday/one-slider` working tree
(main at `70a7b84` plus lane 1's uncommitted edits to `Slider.lean`, `Session.lean`,
`Protocol.lean`, `SessionTests.lean` and the new `Proofs/OneSlider.lean`). Read-only: nothing
was built or run. Line numbers are from the files as they are on `main`.

## 1. The contract this inventory is written against

What the engine does on lane 1's branch, and what lane 1's next commit (Explain.lean) will do:

| Item | Old (`main`) | New |
| --- | --- | --- |
| `new_game` | `{"cmd":"new_game","seed":"42","risk":50,"bluff_pct":33}` | `{"cmd":"new_game","seed":"42","risk":50}`. Any `bluff_pct` field, even in range, is the error `bluff_pct was removed; Risk sets both`. |
| Meaning of `risk` | How heavily a lost chip counts (0 = plain chip profit, 100 = a lost chip counts three times). Higher = more careful. | Appetite for risk. 0 = the rock, 50 = the textbook setting, 100 = the maniac. Higher = looser. **The direction flips.** |
| `state.sliders` | `{"risk": 50, "bluffPct": 33}` | `{"risk": 50, "caution": 0, "bluffPct": 33}`: the player's Risk, then the two internal numbers `Sliders.ofRisk` makes of it. |
| Bot reasons facing a bet | "... at Risk 100 ..." (the internal number) | "... at Risk 0 ..." (the player's number). |
| Bot reason for a river bluff | "Bet 20: a bluff, picked at Bluff 60%." | **Unchanged in the working tree** (`Slider.lean:190` still prints the internal `bluffPct`). See open point 3. |
| Risk explorer entry | `risk`, `actions[0..100]` by internal risk, `continuesUpTo`, `effect` in noBet, raises, callsAlways, foldsAlways, callsUpTo; summary "Calls at Risk 0-37, folds at 38-100." | `risk` = the player's Risk, `actions[r]` = the move at player Risk `r`, `continuesFrom` (lowest Risk at which the bot calls, raises or bets, or null) replaces `continuesUpTo`; `effect` in noBet, raises, callsAlways, foldsAlways, callsFrom, betsAlways, checksAlways, bluffsFrom, varies; summaries flip: "Folds at Risk 0-7, calls at 8-100." and river ones like "Checks at Risk 0-40, bluffs at 41-100: more Risk, more bluffs." |
| Mystery reveal (route, not Lean) | `{"cmd":"reveal","risk":n,"bluff_pct":m}` → `reveal: {risk, bluff_pct, guess:{risk,bluff_pct}, off:{risk,bluff_pct}}` | `{"cmd":"reveal","guess":{"risk":n}}` → `reveal: {risk, off}` with one number each. The route picks one hidden Risk, not a pair. |
| Presets | Ivy (100, 0), Rook (0, 0), Mia (50, 33), Dex (25, 45), Vex (0, 60) | Mia 50, Dex 40, Rook 25, Ivy 0, Vex 100 (the brief's ladder, by distance from 50). |

The mapping, `Sliders.ofRisk r` = (caution, bluffPct), with the values the inventory below uses:

| Player Risk | 0 | 25 | 37 | 40 | 50 | 75 | 100 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| caution | 100 | 50 | 26 | 20 | 0 | 0 | 0 |
| bluffPct | 0 | 17 | 24 | 26 | 33 | 47 | 60 |

## 2. Which recorded (risk, bluff) pairs survive

Every demo scene, practice spot, checklist row and test was recorded at an internal pair. Only
pairs on the `ofRisk` line can be reproduced exactly:

| Old pair (risk, bluff) | Used by | New Risk | Exact? |
| --- | --- | --- | --- |
| (100, 0) Ivy | scene (b), checklist rows 6 and 12, fuzz record | **0** | Yes |
| (0, 60) Vex | scenes (a) and (c), all three practice spots, `demo.test.ts`, http-smoke | **100** | Yes |
| (50, 33) Mia, the default | `insights.test.ts`, `route.test.ts`, `program.test.ts`, `mystery.test.ts`, checklist row 1 | none | **No.** Risk 25 gives caution 50 but Bluff 17; Risk 50 gives Bluff 33 but caution 0. Facing a bet only caution matters, so Risk 25 reproduces every call/fold decision; with no bet on the river only Bluff matters, so Risk 50 reproduces the river bets. No single Risk reproduces a whole hand. Re-record at Risk 50. |
| (0, 0) Rook | checklist rows 3, 4, 7; the shove tests in `route.test.ts`, `mystery.test.ts`, `checks/http-smoke.mjs`; scene (b)'s contrast | none | **No.** Caution 0 needs Risk ≥ 50, which has Bluff ≥ 33. Any Risk ≥ 50 reproduces every decision facing a bet (the all-in calls), but a river bet with no bet to face may differ. Use Risk 50 and re-check. |
| (25, 45) Dex | roster only | none | Gone. |
| (20, 10), (60, 0), (37, 12), (40, 20) | arbitrary test values | n/a | Replace with single Risk values and the table above. |

**The shove tests are the trap.** `route.test.ts:114-120` and `160-170`, `mystery.test.ts:233-235`
and `http-smoke.mjs:56-59` start at (0, 0), raise 500, and expect `gameOver`: the bot must
*call* the all-in (caution 0 calls whenever the call wins chips). If those tests are rewritten
as `risk: 0`, the new Risk 0 is caution 100, the bot folds, the status is `handOver`, and they
fail. Write them as `risk: 50` (or 100).

## 3. Lane 2's files (Devom owns everything under `src/` and `docs/DEMO.md`)

### `src/lean/protocol.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 9-11 | Keep `RISK_MAX = 100`; delete `BLUFF_PCT_MAX`, or keep it only if `review.ts`'s internal checks want to import it (they define their own `MAX_BLUFF_PCT`, so delete). Reword the comment: one setting. | Three importers: `route.ts:6`, `Lobby.tsx:5`, `MysteryGuess.tsx:3`, `roster.test.ts:2`. |
| 15 | `{ cmd: "new_game"; seed: string; risk: number }` | `bluff_pct` is now an error. |
| 84-85 | `sliders: { risk: number; caution: number; bluffPct: number }` with a comment: `risk` is the player's setting, the other two are what it maps to. | New state shape. |
| 170-176 | `LeanRiskEffect = "noBet" \| "raises" \| "callsAlways" \| "foldsAlways" \| "callsFrom" \| "betsAlways" \| "checksAlways" \| "bluffsFrom" \| "varies"`. Rewrite the doc: no-bet moves before the river never read Risk; on the river the bluff share rises with Risk. | `callsUpTo` no longer appears. |
| 190-202 | `risk` = the player's Risk; `continuesUpTo` → `continuesFrom: number \| null` ("the lowest Risk at which the bot calls, raises or bets"); summary example flips: "Folds at Risk 0-37, calls at 38-100." | Contract. |
| 216-218, 226-232 | `RevealCommand = { cmd: "reveal"; guess: { risk: number }; peek?: boolean }`. Mystery doc: the route picks Risk 0-100 and a seed. | Contract. |
| 237-244 | `MysteryReveal = { risk: number; off: number }`. See open point 1 on whether to keep `guess`. | Contract. |
| 252-256 | "would give away the hidden Bluff setting" → "the hidden Risk". | Wording. |

### `src/app/api/game/route.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 4-14 | Drop the `BLUFF_PCT_MAX` import. | |
| 21-22 | Comment: the route picks the bot's Risk at random. | |
| 46-52 | `MysterySecret { engine; risk: number; reveal }`: no `bluffPct`. | One hidden number. |
| 104-108 | `if (!isCount(b.risk)) return null;` and build `{ cmd: "new_game", seed, risk: b.risk }`. Decide what to do with a stray `bluff_pct` (open point 2). | Today the route *requires* `bluff_pct` (line 105) and forwards it (108); against the new engine every game start would be refused. |
| 124-127 | `{ kind: "reveal"; risk: number; peek: boolean }`. | |
| 139-144 | A Mystery `new_game` must still carry no `risk`; keep turning away `bluff_pct` too (any slider field is a mistake). | |
| 146-149 | Parse `b.guess?.risk`: a whole number 0..`RISK_MAX`; else 400. | New request shape. |
| 198, 219-224 | `reveal(lean, guess: { risk; peek })`; `m.reveal = { risk: m.risk, off: Math.abs(guess.risk - m.risk) }`. | |
| 248, 252-254 | `picked = { risk: randomInt(RISK_MAX + 1) }`; the command has no `bluff_pct`. | |
| 184-186 | Comment: "at its Bluff setting" → "at the bluff share its Risk maps to". | Wording. |

### `src/hooks/useGame.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 19-33 | `GameSettings`: drop `bluffPct`; reword `risk` (appetite for risk, 0 to 100) and the Mystery note (the server picks Risk and the seed). | |
| 28-30, 37 | Wording: "the sliders" → "the slider". | |
| 410 | `botFor(settings.risk)`. | `roster.ts` signature. |
| 418 | `{ cmd: "new_game", seed: ..., risk: settings.risk }`. | |
| 441, 443, 448 | `GameSettings` and `botFor` from `challenge.risk` only; the `new_game` body has no `bluff_pct`. | `challenges.ts` loses `bluff_pct`. |
| 537-546 | `reveal(risk: number)`; body `{ cmd: "reveal", guess: { risk } }`. | New request shape. |

### `src/components/Lobby.tsx`

| Lines | Change | Why |
| --- | --- | --- |
| 5 | Import `RISK_MAX` only. | |
| 43-44 | Doc: pick a named opponent or set the bot's Risk. | |
| 57-64 | Drop `bluffPct` state; `presetFor(risk)`; `pick(risk)`. Default 50 stays (Mia is 50 in the new ladder). | |
| 72 | `onStart({ risk, seed, fast, mystery })`. | |
| 95 | "picks the bot's Risk at random". | |
| 109 | `pick(o.risk)`. | |
| 123 | "Move the slider to build your own". | |
| 128-135 | The Risk help text must flip direction. Today: "How much the bot hates losing chips: at 0 it calls whenever calling pays off on average, and at 100 it needs a much stronger hand to call." Suggested: "Appetite for risk. 0 is a rock: it folds unless a call clearly pays, and never bluffs. 50 plays the textbook way. 100 is a maniac: it bluffs 60% of its river bets." Never "optimal" or "GTO" (brief). | Direction flips. |
| 136-143 | Delete the Bluff slider. | |

### `src/components/MysteryGuess.tsx`

| Lines | Change | Why |
| --- | --- | --- |
| 3 | Import `RISK_MAX`, `MysteryReveal` only. | |
| 13 | `onGuess: (risk: number) => void`. | |
| 19-29 | `CLOSE = 10`; `verdict`: close if `r.off <= 10`, else not close. Two sentences instead of four. | One number. |
| 31, 52 | Doc and prompt: one slider, the hidden Risk. | |
| 34, 63-70 | Drop `bluffPct` state and the Bluff slider. | |
| 60 | Help text flips: today "High Risk folds more to big bets; low Risk calls more." → "Low Risk folds to big bets and never bluffs; high Risk calls more and bluffs more." | Direction flips. |
| 78 | `onGuess(risk)`. | |
| 90-113 | One table row: Your guess, Real, Off by. The guess column reads the component's own `risk` state if the reply has no `guess` (open point 1). Drop the Bluff row. | |

### `src/components/GameOver.tsx`

| Lines | Change | Why |
| --- | --- | --- |
| 11-15 | `replay.sliders: { risk: number } \| null` (or the full new shape; only `risk` is shown). | |
| 66 | "Change sliders" → "Change the bot" or "Change Risk". | |
| 73-78 | One span: Risk. Drop the Bluff span. Optionally show caution and bluffPct in a `title` for the replay record. | The replay record needs seed, Risk, turn mode and commits. |

### `src/components/PokerApp.tsx`

| Lines | Change | Why |
| --- | --- | --- |
| 84-86 | `submitGuess(risk)`; `reveal(risk)`. | |
| 180 | `shownSliders = mystery ? (game.lean.sliders ?? null) : { risk: game.settings.risk }`. | |
| 210-214 | Title "The bot's Risk for this game"; text `Risk ${shownSliders.risk}`. | |
| 236 | "Guess the bot's Risk". | |
| 319-324 | `sliders: game.lean.sliders ?? null` is fine if `GameOver` takes the new shape. | |
| 328 | **Bug if left as is:** `{ ...game.settings, ...(game.lean.sliders ?? {}) }` would copy `caution` and `bluffPct` into `GameSettings`. Write `{ ...game.settings, risk: game.lean.sliders?.risk ?? game.settings.risk, mystery: false, seed: replaySeed }`. | New state shape. |
| 339 | `onGuess={(risk) => void submitGuess(risk)}`. | |

### `src/components/RiskExplorer.tsx`

No field change needed: it reads `risk`, `action`, `actions`, `counts`, `toCall`, `pot`,
`riskMatters` and `summary` only, never `continuesUpTo` or `effect`. Lines 33-34 and 70 already
say "Risk from 0 to 100", which now means the player's Risk. Verify the marker at line 78
(`left: ${entry.risk}%`) still points at the bot's real setting: it does, since `risk` is the
player's number.

### `src/components/ReviewModal.tsx`

Line 159: "until its settings are revealed" → "until its Risk is revealed". Nothing else.

### `src/components/RangeViewer.tsx`

Line 5 comment ("the Bluff guarantee") and line 40 `onShowProof("bluff")`: the id `bluff` can
stay (it is the T7 entry's id in `guarantees.ts`); only the comment wording changes. Line 25's
sentence ("value" and "bluffs" counts) is still right: the set still has value hands and bluffs.

### `src/components/Seat.tsx`, `Table.tsx`, `ChallengePicker.tsx`, `ProofsDrawer.tsx`

No slider references. No change.

### `src/lib/roster.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 1-12 | `Opponent { name; color; style; risk }`: the one Risk, 0 to 100. Doc: every opponent is the same proven bot at a different Risk. | |
| 14-21 | The ladder: Ivy 0 ("Rock: folds unless clearly ahead, never bluffs"), Rook 25 ("Folds too much, rarely bluffs"), Dex 40 ("Solid: slightly careful"), Mia 50 ("The textbook setting"), Vex 100 ("Maniac: bluffs 60% of its river bets"). Keep the order "most careful to wildest" = ascending Risk. Keep the colors. | Brief step 6. Do not say "optimal" or "GTO". |
| 27-29, 32-35 | `presetFor(risk)`, `botFor(risk)`: match on `risk` only. | |

### `src/lib/challenges.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 4-13 | Doc: "the spot's seed and Risk". Note that the spots were recorded at the old pair (0, 60), which is exactly Risk 100 now. | |
| 29-30 | Drop `bluff_pct`; `risk` becomes the player's Risk. | |
| 49-50, 63-64, 77-78 | `risk: 100` for all three spots. The labels, worths and results do not change: the internal pair is the same. | (0, 60) = `ofRisk 100`. |

### `src/lib/guarantees.ts`

| Lines | Change | Why |
| --- | --- | --- |
| 79-105 (T4) | The plain words are about the *internal* number and now read backwards for the player. Either (a) keep the theorems as listed and say explicitly "Risk here is the bot's internal caution number, which falls as the Risk you set rises", or (b) once lane 1's `more_risk_never_folds_a_call`, `ofRisk_caution_antitone`, `ofRisk_bluff_monotone` and `ofRisk_bluff_le_60` are in `comparator.json`, add them and rewrite `says` in player terms: "if the bot calls or raises at some Risk, it also calls or raises at every *higher* Risk". Line 85 ("once at Risk 0, twice at Risk 50, three times at Risk 100") flips to "three times at Risk 0, twice at Risk 25, once at Risk 50 and above". `assumes` line 98: "the same Bluff setting" → "the same bluff share". | `guarantees.test.ts:11-13` fails the build if a listed theorem is not in `comparator.json`, so (b) can only land after lane 1's theorem commit. |
| 144-159 (T7) | Title "The Bluff slider sets the bluffs in the river betting set" → "Risk sets the bluffs in the river betting set". `says`: the bluff share is the one Risk maps to (0% at Risk 0, 33% at Risk 50, 60% at Risk 100). `assumes` line 154: "Bluff is 0 to 60" → "the bluff share Risk maps to is at most 60 (`ofRisk_bluff_le_60`)", once registered. | |
| 66 | "at every slider setting" → "at every Risk". | Wording. |
| 10-11 | The ids `risk` and `bluff` can stay; `guarantees.test.ts:16-25, 43-47` pin them. | |

### `src/ai/slider/fromHand.ts`, `decide.ts`, `decide.test.ts`, `src/review/review.ts`, `riverStrategy.ts`, `review.test.ts`, `riverStrategy.test.ts`

**No code change.** These are the TypeScript reference for the *internal* bot (`Sliders` =
caution and bluffPct), which lane 1 keeps unchanged, and `SliderTests.lean` compares against
them. Optional: one comment in `decide.ts:12` and `fromHand.ts:21-22` saying `risk` here is the
internal caution number, not the slider the player sees. `riverStrategy.ts:13-14`'s
`MAX_BLUFF_PCT` stays.

### `src/app/layout.tsx`, `src/app/globals.css`

`layout.tsx:8`: "one bot you build with two sliders, Risk and Bluff" → "one bot you build with
one slider, Risk". `globals.css:1010` and `:1532` are comments naming the sliders; reword.

### Tests under `src/` that send `new_game` or read `sliders`, `continuesUpTo`, `effect`

| File | Lines | Change |
| --- | --- | --- |
| `src/app/api/game/route.test.ts` | 38-41, 47 | Drop `bluff_pct`; rename "without sliders" → "without Risk". Add a case for `guess` shapes if the reveal parser moves here. |
| | 71, 83 | Stand-in programs; any body. Drop `bluff_pct`. |
| | 96, 114-120, 160-170 | **Shove tests**: `risk: 50`, not 0 (section 2). Line 170: `sliders: { risk: 50, caution: 0, bluffPct: 33 }`. |
| | 175, 203, 232, 243, 253 | `risk: 50` (or 25 if the recorded behaviour must match; these only need a running game). |
| | 226-228 | Keep `risk: 101` → "risk must be 0-100". Add: `{ risk: 50, bluff_pct: 33 }` → whatever open point 2 decides (400 from the route, or Lean's "bluff_pct was removed; Risk sets both"). |
| `src/app/api/game/insights.test.ts` | 27-32, 104 | Seed 7 was recorded at (50, 33), not reachable. Re-record at `risk: 50` (caution 0, Bluff 33). The bot still has 160 bluffs (line 63 holds). Whether it still calls the raise to 30, checks flop and turn and bets 60 on the river must be re-checked by running it. |
| | 78 | `e.risk` is 50: still true. |
| | 81-83 | Flips: as Risk rises the bot never goes from a call back to a fold. Find the first non-Fold index; everything after it must be non-Fold. |
| | 85 | No longer holds: a river move with no bet to face is `betsAlways`, `checksAlways` or `bluffsFrom`, not `noBet`. Replace with: `effect === "noBet"` implies `toCall === 0`; and `toCall > 0` implies effect in raises, callsAlways, foldsAlways, callsFrom. |
| | 86 | `riskMatters === ["callsFrom", "bluffsFrom", "varies"].includes(effect)`. |
| | 88-93 | For `callsFrom`: `k = continuesFrom`; `actions[k - 1] === "Fold"`, `actions[k] === "Call"`; summary `Folds at Risk 0-${k - 1}, calls at ${k}-100.` |
| | 97-98 | `entries[0]`: `effect` is `callsFrom` with `continuesFrom <= 50`, or `callsAlways`. |
| | 100 | `entries[3]` "Bet 60" is a river value bet: `effect: "betsAlways"`, `riskMatters: false`, `continuesFrom: 0`. (If the summary wording for `betsAlways` is fixed by lane 1, pin it too.) |
| `src/app/api/game/mystery.test.ts` | 35 | The leak regex `/\b(Risk\|Bluff)\s*\d/` still catches both words; keep. Also add `"caution"` to `SECRET_KEYS` (line 28) since the new state carries it. |
| | 92, 104-115 | Bad guesses become: `{ guess: { risk: 101 } }`, `{ guess: { risk: -1 } }`, `{ guess: { risk: 50.5 } }`, `{ guess: { risk: "50" } }`, `{}`, `{ risk: 50 }` (the old flat shape), `{ guess: {} }`. |
| | 119-129, 138, 141 | `post({ cmd: "reveal", guess: { risk: 40 } })`; `r.risk` in 0..100; `r.off === Math.abs(40 - r.risk)`; `reply.state.sliders.risk === r.risk` (and `caution`, `bluffPct` present). |
| | 164-167 | `guess: { risk: 0 }`; compare `sliders.risk` with `reveal.risk`. |
| | 173-176 | Keep: a Mystery game sent with `risk` or `bluff_pct` is turned away. |
| | 187-188, 196-197, 202-204, 212, 216-217, 221-222 | Single `risk`; `sliders` expectations use the table in section 1, e.g. `risk: 20` → `{ risk: 20, caution: 60, bluffPct: 13 }` (33·20+25 = 685, /50 = 13). |
| | 233-235 | **Shove test**: `risk: 50`; `sliders: { risk: 50, caution: 0, bluffPct: 33 }`. |
| `src/lean/program.test.ts` | 81 | `newGame = (seed, risk = 50) => send({ cmd: "new_game", seed, risk })`. |
| | 91-92 | Keep `risk: 101`; replace the `bluff_pct: 61` case with `{ seed: "1", risk: 50, bluff_pct: 33 }` and expect the error text `bluff_pct was removed; Risk sets both`. |
| | 101-105 | Both ends and a middle: `0 → { risk: 0, caution: 100, bluffPct: 0 }`, `100 → { risk: 100, caution: 0, bluffPct: 60 }`, `37 → { risk: 37, caution: 26, bluffPct: 24 }`. |
| `src/app/api/game/demo.test.ts` | 18 | `{ cmd: "new_game", seed: "6", risk: 100 }`. Everything else is unchanged: same internal pair. |
| `src/lib/challenges.test.ts` | 22 | `{ cmd: "new_game", seed: c.seed, risk: c.risk }`. |
| `src/lib/roster.test.ts` | 2, 9 | Import `RISK_MAX` only; drop the `bluffPct` range check. |
| | 15 | Uniqueness by `o.risk`. |
| | 20-24 | `presetFor(o.risk)`, `botFor(o.risk)`; `presetFor(51)` undefined; `botFor(51)` is the custom bot. |
| | 27-28 | "the default Risk 50 is Mia": `presetFor(50)?.name === "Mia"`. |
| `src/lib/guarantees.test.ts` | none | Unchanged, but it enforces the ordering in the `guarantees.ts` row above. |
| `src/ai/slider/decide.test.ts`, `src/review/*.test.ts` | none | Internal bot; unchanged. |

### `docs/DEMO.md` (lane 2)

| Lines | Change |
| --- | --- |
| 51-53 | Ivy (Risk 0); Vex (Risk 100). |
| 55 | "Picking one sets the slider." |
| 57, 59 | "Scene (b): Risk 0. The bot folds to a big bet." Pick Ivy (Risk 0). |
| 66-67 | The reason becomes "Fold: not worth calling 140 to win 160 at Risk 0, with win chance 58%." |
| 68-70 | Rook (0, 0) is gone. The contrast is Mia (Risk 50) with the same raise: the bot calls 140 (any Risk ≥ 50 has caution 0, so the call is the same). The sentence flips: "This is the direction the proof allows: less Risk can turn a call into a fold, never a fold into a call" (`more_risk_never_folds_a_call`). |
| 72, 74 | "Scene (c): Risk 100. The bot bluffs the river." Pick Vex (Risk 100). |
| 87, 90 | Unchanged unless lane 1 changes the river bluff reason (open point 3). |
| 98 | Pick Vex (Risk 100). |
| 124, 144 | `{"cmd":"new_game","seed":"6","risk":100}`. |
| 170-174 | Column "Risk"; every row 100. |
| 191 | Mia (Risk 50), seed 1, fold: the bot makes no move, so the expected text is unchanged. |
| 192, 195, 200, 209 | Vex (Risk 100). |
| 193, 197 | Rook (0, 0) → Mia (Risk 50): the all-in call (a decision facing a bet) is the same at caution 0. Re-check in the browser. |
| 194 | Rook (0, 0) → Mia (Risk 50), **but re-record**: hand 1 "the bot checks every street" was at Bluff 0; at Bluff 33 the bot may bet a river bluff. Hand 2's all-in call is unchanged. |
| 196 | Ivy (Risk 0). |
| 210 | Risk explorer: "The bot's preflop decision folds at Risk 0 and calls at Risk 100. There is one change point between them." The old summary for this spot was "Calls at Risk 0-29, folds at 30-100" (`DEMO_QUICKSTART.md:53`): caution ≤ 29 calls, and caution 29 is Risk 36 (100 − 2·36 = 28 ≤ 29; Risk 35 gives 30). Expected new summary: "Folds at Risk 0-35, calls at 36-100." Verify by running. |
| 213 | "The reveal shows the true Risk, and how close the guess was." |
| 215-220 | See section 6. |

## 4. Unowned files (not lane 1's, not under `src/` or `docs/DEMO.md`)

Lane 1's draft pull request runs the `app` CI job (`.github/workflows/lean-proofs.yml:60-82`):
`make install`, `npm run typecheck`, `npm test`, then `checks/http-smoke.mjs` against the
production server. **That job is red on the protocol-only commit** until `route.ts`, the tests
and `http-smoke.mjs` change, because `route.ts:105` refuses a `new_game` without `bluff_pct`
and `route.ts:108` forwards it to an engine that now rejects it. The `proofs` job can be green
on its own.

### `checks/http-smoke.mjs` (CI; nobody is named)

| Lines | Change |
| --- | --- |
| 28 | `{ cmd: "new_game", seed: scene.seed, risk: scene.risk }`; `scene.risk` is 100 once `scenes.json` is rewritten. |
| 53 | `entry.actions[entry.risk] === entry.action` still holds. |
| 56-59 | **Shove**: `risk: 50`, not 0, or `finished.status` is `handOver`. |
| 64, 81 | `{ cmd: "reveal", guess: { risk: 50 } }` → 400. |
| 77-80 | `revealed.state.sliders.risk === revealed.reveal.risk`; drop the `bluffPct` line, or check `caution` and `bluffPct` against a four-line `ofRisk` copied into the script. |

### `docs/demo/find-demo-hands.mjs`, `scenes.json`, `challenges.json` (the demo records)

| File, lines | Change |
| --- | --- |
| `find-demo-hands.mjs:110-116, 141` | `newGame(seed, risk)`; `playToRiver(engine, seed, risk, line)`. |
| `:129-131` | `roleOf` matches `/a bluff, picked at Bluff/`. Keep only if lane 1 keeps that reason text (open point 3); otherwise match the new text. |
| `:182-183, 265-266, 422-424` | Drop `bluff_pct` from the records. |
| `:253-258` | `RIVER_SLIDERS = [{ risk: 100 }, { risk: 50 }, { risk: 0 }]`. The middle one was (50, 33); the new Risk 50 is (0, 33), a different bot. |
| `:295-298` | Scene (b): title "Risk 0: the bot folds to a big bet"; `risk: 0`. |
| `:304, 342, 373` | `same_seed_at_risk_0` → `same_seed_at_risk_50` (the contrast game at Risk 50, caution 0). The recorded `events` (`scenes.json:109-135`) are the preflop raise, the bot's call and its flop check; a later river bluff at Bluff 33 would add events, so re-record. |
| `:315-334` | `sliders.risk === 100` for scene (c) and the `catch-bluff` spot. |
| `:403` | Scene (c) title "Risk 100: the bot bets a designated bluff on the river". |
| `scenes.json:6-7, 141-142` | `"risk": 100`, no `bluff_pct`. |
| `scenes.json:92-95` | Title "Risk 0: ..."; `"risk": 0`. |
| `scenes.json:106` | `"Fold: not worth calling 140 to win 160 at Risk 0, with win chance 58%."` |
| `scenes.json:109-135` | Rename and re-record (above). |
| `scenes.json:47, 181`, `challenges.json:68, 162, 261` | Reason texts; unchanged unless open point 3 changes them. |
| `challenges.json:6-7, 102-103, 199-200` | `"risk": 100`, no `bluff_pct`. |

Regenerate with `node docs/demo/find-demo-hands.mjs --write` on the merged engine rather than
editing by hand, then diff: only `risk`, the dropped `bluff_pct`, the two titles, scene (b)'s
reason and the renamed contrast block should differ.

### `docs/PITCH.md` (lane 3)

| Lines | Change |
| --- | --- |
| 13-15 | Ivy (Risk 0); Vex (Risk 100). |
| 26, 28-29 | "Pick Ivy: Risk 0." "At Risk 0, a lost chip counts three times as much as a won chip." |
| 31-32 | "... at Risk 0, with win chance 58%." |
| 37-40 | Rook is gone: "the same seed with Mia (Risk 50)". The lines flip: "Same cards, same raise, more Risk: now it calls. Raising Risk can turn a fold into a call. Lowering Risk can never turn a fold into a call." |
| 44 | "Pick Vex: Risk 100." |
| 50 | "Risk 100 means 60% of the hands it bets on the river are bluffs." |
| 53, 59-61 | Unchanged unless open point 3. |
| 93-95 | "At the same decision, lowering Risk never turns a fold into a call or a raise" (or "raising Risk never turns a call into a fold"); "Risk sets how many bluffs are in the bot's river betting set, to the nearest whole hand." |
| 122-125 | Claim table: name `more_risk_never_folds_a_call`, `ofRisk_bluff_le_60` and `ideal_river_set` once registered; "same Bluff" → "same bluff share"; "at every lower Risk" → "at every higher Risk". |
| 137 | Wording. |

### `docs/DEMO_QUICKSTART.md`

Line 48: Ivy (Risk 0). Line 53: the explorer sentence flips, expected "Folds at Risk 0-35,
calls at 36-100." (see the `DEMO.md:210` row). Line 8 and 74: wording.

### `docs/proofs-bot-equity.md`

Line 8: "The bot has two sliders" → one slider mapped to two internal numbers. Line 40:
"calls at Risk 100 but folds at Risk 0" describes the internal number; say so or flip it.

### `README.md`, `SPEC.md`, `MVP.txt`

- `README.md:31` "Risk/Bluff sliders" → "one Risk slider"; `:57` "sliders" → "Risk".
- `SPEC.md:40-42` (T4) and `:55-58` (T7) are stated over the internal numbers and stay true.
  Add one paragraph: the player sets one Risk; `Sliders.ofRisk` maps it; the direction of
  "Risk" in T4 is the internal caution, which falls as the player's Risk rises; name the
  new theorems. `:134` list the new names once registered.
- `MVP.txt` is the human-owned product definition and describes the old two-slider design at
  lines 20, 34, 47-52, 67, 155, 161, 169, 180, 190, 207, 231, 238-239, 246 and 256. Do not
  rewrite it piecemeal: add a dated "Sunday change: one Risk slider" note at the top that
  states the mapping and points at `docs/THEORY.md`, and fix §13's JSON at 207 and 231.

### `tools/fuzz-engine.mjs`, `docs/validation/integration-fuzz.json`

- `fuzz-engine.mjs:303-306` (bad-input cases: drop the "bluff out of range" case, add
  "bluff_pct present"), `:338-340, 354-356, 388, 448, 560` (games are a `RISKS × BLUFFS`
  grid; make it a `RISKS` list and send `risk` only).
- `integration-fuzz.json:97-98` is a record of a past run at (100, 0). Leave it as history or
  re-run the fuzzer on the merged engine; do not hand-edit.

## 5. Open points (decide before coding)

1. **Does the reveal reply keep `guess`?** The brief says `{risk, off}`. `MysteryGuess.tsx:102`
   shows "Your guess" from `reveal.guess.risk`; `mystery.test.ts:127` asserts it. Either keep
   `guess: { risk }` in the reply (smallest change) or have the component show its own slider
   state. Lane 2's call, since `route.ts` is theirs.
2. **A stray `bluff_pct` at the HTTP route.** Today the route builds the Lean command from
   named fields, so an old client's `bluff_pct` would be silently dropped and the game would
   start. To keep "fails loudly" at the HTTP level, either turn it away with 400 in
   `parseGameCommand` or forward it so Lean answers "bluff_pct was removed; Risk sets both".
   Recommend 400 at the route with the same message, and a route test for it.
3. **The river bluff reason still prints the internal number**: `Slider.lean:190` gives
   "a bluff, picked at Bluff 60%". With one slider there is no Bluff the player set. Lane 1
   decides: keep it (then `scenes.json`, `challenges.json`, `DEMO.md:87,90`, `PITCH.md:53` and
   `find-demo-hands.mjs:131`'s regex stay), or change it to "a bluff: Risk 100 bluffs 60% of
   its river bets" (then all five change). Tell lane 2 which.
4. **`guarantees.ts` can only name the new theorems after they are in `comparator.json`**
   (`guarantees.test.ts:11-13`). So lane 1's theorem commit must land before, or together with,
   lane 2's drawer wording; the protocol-only commit must not be the one lane 2 rebases the
   drawer change onto.
5. **The explorer's `risk` for pre-river no-bet moves.** `noBet` entries have
   `continuesFrom` null or 0; pin which in the contract so `insights.test.ts:100` can assert it.
6. **CI order.** The `app` job is red from lane 1's protocol commit until lane 2's web commit
   lands on top (section 4). Merge both before reading CI as a verdict, or merge the web change
   into lane 1's branch first.

## 6. "After the merges" checklist, adapted (replaces `docs/DEMO.md:215-220`)

1. Build the merged engine once, in one checkout. Confirm `state.sliders` has three fields and
   `new_game` with `bluff_pct` is refused.
2. Run `node docs/demo/find-demo-hands.mjs --check` with `POKER_BIN` set to that build. Expect
   `FAIL` on first run: the records still carry `bluff_pct` and scene (b)'s reason says
   "at Risk 100".
3. Run `node docs/demo/find-demo-hands.mjs --write`. Diff `scenes.json` and `challenges.json`
   against `main`: only `risk` (0 for scene (b), 100 elsewhere), the dropped `bluff_pct`, the two
   titles, scene (b)'s reason ("at Risk 0") and the renamed contrast block may differ. Any
   change to cards, moves, labels, worths or equities means the internal pair changed; stop and
   ask lane 1.
4. Update `docs/DEMO.md`, `docs/PITCH.md`, `docs/DEMO_QUICKSTART.md`,
   `src/app/api/game/demo.test.ts` and `src/lib/challenges.ts` together.
5. Run `npm run typecheck` and `npm test` with `POKER_BIN` set. `demo.test.ts`,
   `challenges.test.ts`, `insights.test.ts`, `mystery.test.ts`, `route.test.ts`,
   `program.test.ts`, `roster.test.ts` and `guarantees.test.ts` must pass. Record the new
   explorer summaries that `insights.test.ts` pins.
6. Start the app and run `node checks/http-smoke.mjs` against it (`APP_URL`).
7. In the browser: scene (b) with Ivy (Risk 0), the contrast with Mia (Risk 50), scene (c) and
   (a) with Vex (Risk 100), checklist rows 3, 4 and 7 with Mia (Risk 50), the Mystery guess
   with one slider, and the Risk explorer on scene (b) (expected "Folds at Risk 0-35, calls at
   36-100"). Re-record row 4's hand 1 if the bot bets the river.
8. Update "What the hands were checked on" with the new engine hash and commit, and the CI run
   link for the merged commit (both jobs green).
