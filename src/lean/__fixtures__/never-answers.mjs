// A stand-in for the Lean game program that reads commands but never answers, as a hung
// program would. Used by src/app/api/game/route.test.ts through POKER_BIN.
process.stdin.resume();
setInterval(() => {}, 60_000);
