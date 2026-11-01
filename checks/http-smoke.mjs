import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Run against a dedicated server: this replaces its single local game.
const base = process.env.APP_URL ?? "http://localhost:3001";
async function post(body, status = 200) {
  const response = await fetch(`${base}/api/game`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
    signal: AbortSignal.timeout(60_000),
  });
  const reply = await response.json();
  assert.equal(response.status, status, JSON.stringify(reply));
  return reply;
}
function accepted(reply) {
  assert.equal(reply.ok, true, JSON.stringify(reply));
  return reply.state;
}
function hidden(reply) {
  assert.equal(reply.state.seed, null);
  assert.equal("sliders" in reply.state, false);
  assert.equal("botReasons" in reply.state, false);
  assert.equal("review" in reply, false);
}

assert.equal((await fetch(base)).status, 200);
const [scene] = JSON.parse(readFileSync(new URL("../docs/demo/scenes.json", import.meta.url), "utf8"));
let state = accepted(await post({ cmd: "new_game", seed: scene.seed, risk: scene.risk, bluff_pct: scene.bluff_pct }));
assert.equal(state.seed, null);
assert.equal(state.players[1].cards, null);
assert.equal(state.turnMode, "exact");
const peeked = accepted(await post({ cmd: "state", peek: true }));
assert.equal(peeked.players[1].cards.length, 2);
assert.equal(peeked.seed, null);
assert.equal(accepted(await post({ cmd: "state" })).players[1].cards, null);
const rejected = await post({ cmd: "act", action: "raise", amount: 1 });
assert.ok(rejected.error);
assert.equal(rejected.state.seed, null);
for (const move of scene.moves) state = accepted(await post({ cmd: "act", ...move }));
assert.equal(state.street, "river");
state = accepted(await post({ cmd: "act", action: "call" }));
assert.notEqual(state.status, "playing");
assert.equal(state.seed, null);
const reviewed = await post({ cmd: "review", hand: state.hand });
const decision = reviewed.review.decisions.findLast(d => d.label !== null);
assert.equal(decision.label, scene.labels.call);
assert.deepEqual(decision.worth_bb, scene.worth_bb);
const range = decision.range;
assert.equal(range.value + range.bluffs, range.blocked + range.beat + range.tie + range.lose);
assert.ok(reviewed.review.risk_explorer.length > 0);
for (const entry of reviewed.review.risk_explorer) {
  assert.equal(entry.actions.length, 101);
  assert.equal(entry.actions[entry.risk], entry.action);
}

accepted(await post({ cmd: "new_game", seed: "1", risk: 0, bluff_pct: 0 }));
const finished = accepted(await post({ cmd: "act", action: "raise", amount: 500 }));
assert.equal(finished.status, "gameOver");
assert.equal(finished.seed, "1");

let mystery = await post({ cmd: "new_game", mystery: true });
accepted(mystery);
hidden(mystery);
await post({ cmd: "reveal", risk: 50, bluff_pct: 33 }, 400);
for (let hand = 0; hand < 3; hand++) {
  if (mystery.state.status === "playing") mystery = await post({ cmd: "act", action: "fold" });
  accepted(mystery);
  hidden(mystery);
  const deferred = await post({ cmd: "review", hand: mystery.state.hand });
  hidden(deferred);
  assert.equal(deferred.reviewDeferred, true);
  if (mystery.state.status === "gameOver" || hand === 2) break;
  mystery = await post({ cmd: "next_hand" });
  accepted(mystery);
  hidden(mystery);
}
const revealed = await post({ cmd: "reveal", risk: 50, bluff_pct: 33 });
accepted(revealed);
assert.equal(revealed.state.sliders.risk, revealed.reveal.risk);
assert.equal(revealed.state.sliders.bluffPct, revealed.reveal.bluff_pct);
await post({ cmd: "reveal", risk: 50, bluff_pct: 33 }, 400);
console.log("PASS: production HTTP game, Peek, rejected move, graded review, range, Risk explorer, replay seed and Mystery reveal");
