import { useId, useState } from "react";
import { CITATIONS, type CitationKey } from "@/lib/citationsStub";
import styles from "./review.module.css";

/** Each idea's heading in the "Why?" panel. */
const IDEA: Record<CitationKey, string> = {
  "pot-odds": "The chance a call needs",
  "bluff-ratio": "How many bluffs a bet holds",
  "min-defense": "How often to call",
  "risk-weight": "How Risk weighs a loss",
  "exact-equity": "How the chances are counted",
  "grade-bands": "The five labels",
};

/**
 * A "Why?" chip: it opens the published sources behind the ideas a review line uses. They
 * back up the ideas. They are not proofs; the proofs are in "What is guaranteed?".
 */
export function WhyChip({ ideas }: { ideas: CitationKey[] }) {
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const shown = ideas.filter((key) => CITATIONS[key].length > 0);
  if (shown.length === 0) return null;
  return (
    <div className={styles.why}>
      <button type="button" className={styles.whyChip} aria-expanded={open} aria-controls={panelId} onClick={() => setOpen((o) => !o)}>
        Why?
      </button>
      {open && (
        <div id={panelId} className={styles.whyPanel}>
          {shown.map((key) => (
            <section key={key}>
              <h4>{IDEA[key]}</h4>
              <ul>
                {CITATIONS[key].map((c) => (
                  <li key={c.id + c.short}>
                    {c.claim} <cite>{c.short}</cite>
                    <span className={styles.citeId}> [{c.id}]</span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          <p className={styles.whyFoot}>Sources are listed in docs/research/sources. They support the ideas; they are not proofs.</p>
        </div>
      )}
    </div>
  );
}
