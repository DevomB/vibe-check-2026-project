# Summary: E04: DIVAT (Billings and Kan, "A Tool for the Direct Assessment of Poker Decisions")

TL;DR: DIVAT judges each betting round of limit hold'em in hindsight (both players' cards known) by comparing the money actually put in to a "baseline" sequence that two honest bet-for-value players would have used. The per-round "DIVAT Difference" sums to a low-variance skill score. Unbiasedness of the roll-out version was proved by Zinkevich et al. 2006 (on paper).
- Skill = (equity difference between actual betting and baseline betting). Luck is what is left.
- Uses hindsight knowledge of all cards. Fine for long-run measurement, but per-decision verdicts that use the opponent's hidden cards would break our "no hidden cards" rule.
- Baseline uses simple threshold rules (fold below bs/(ps+bs) + offset), which look a lot like our rule-based bot.
- Empirical variance reductions of 5.50x to 6.34x in limit matches.
- Useful as a historical precedent and pitch line ("Alfred lost 11 sb but played +1.46 sb better").

Verdict: maybe. Good background and a good worked example; AIVAT (E03) is the method we should actually follow.


Full extraction: [notes.md](notes.md).
