# Summary: E10: MIVAT, "Learning a Value Analysis Tool for Agent Evaluation" (White and Bowling, IJCAI 2009)

**Source:** White, Bowling. "Learning a Value Analysis Tool for Agent Evaluation." IJCAI 2009. https://www.ijcai.org/Abstract/09/326

TL;DR: MIVAT writes the identity we want in one line: actual result = skill + luck + position, where skill sums value changes at players' actions, luck sums value changes at chance events, and position is the value at the start (their Equation 9). If the value before each chance event is the probability-weighted average of the values after it (the "zero-luck constraint"), luck has mean zero and "skill + position" is an unbiased estimate. The paper then learns the value function from data.
- Equation 9 is exactly our seed theorem "EV + luck = actual result". It holds on every single hand by cancellation (telescoping); no probability needed.
- The zero-luck constraint (Equation 11) is a definition, so luck's mean zero is a short finite-sum lemma.
- In MIVAT, "skill" includes ALL players' actions (bot too). Since our bot is known code, AIVAT (E03) lets us move the bot's action terms into luck. For a deterministic bot those terms are 0 anyway.
- The value function can be anything that satisfies Eq. 11 at chance nodes; a learned or heuristic one is fine. Good news for our "labeled estimates" before the river.

Verdict: use. It gives the exact, citable statement of "skill + luck + position = result".


Full extraction: [notes.md](notes.md).
