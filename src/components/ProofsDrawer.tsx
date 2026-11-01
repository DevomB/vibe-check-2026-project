import { useEffect, useRef } from "react";
import { GUARANTEES, TRUSTED } from "@/lib/guarantees";
import styles from "./modes.module.css";

interface Props {
  /** The guarantee to scroll to and mark, like "review"; null opens at the top. */
  focus: string | null;
  onClose: () => void;
}

/** "What is guaranteed?": each Lean guarantee in plain words, with its theorem names, what it
 * assumes and what it does not cover, then what the guarantees rest on without a proof. */
export function ProofsDrawer({ focus, onClose }: Props) {
  const bodyRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Capture first and stop there, so Escape closes only the drawer, not a review under it.
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      e.stopPropagation();
      onClose();
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [onClose]);

  useEffect(() => {
    const body = bodyRef.current;
    if (!body) return;
    const entry = focus ? body.querySelector<HTMLElement>(`[data-guarantee="${focus}"]`) : null;
    if (entry) entry.scrollIntoView({ block: "start" });
    else body.scrollTop = 0;
  }, [focus]);

  return (
    <div className={styles.drawerBackdrop} onClick={onClose}>
      <aside className={styles.drawer} role="dialog" aria-label="What is guaranteed?" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Close">
          ×
        </button>
        <h2>What is guaranteed?</h2>
        <p className={styles.drawerIntro}>
          Each item is a theorem that Lean checks against the engine's own code. It means only what is written here.
        </p>
        <div className={styles.drawerBody} ref={bodyRef}>
          {GUARANTEES.map((g) => (
            <section key={g.id} data-guarantee={g.id} className={`${styles.guarantee} ${g.id === focus ? styles.isFocus : ""}`}>
              <h3>
                <span className={styles.code}>{g.code}</span> {g.title}
              </h3>
              <ul>
                {g.says.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
              <h4>It assumes</h4>
              <ul>
                {g.assumes.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
              <h4>It does not cover</h4>
              <ul>
                {g.limits.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
              <h4>Lean theorems</h4>
              <p className={styles.theorems}>
                {g.theorems.map((t) => (
                  <code key={t}>{t}</code>
                ))}
              </p>
            </section>
          ))}
          <section className={styles.guarantee}>
            <h3>What we trust</h3>
            <p className={styles.drawerIntro}>The guarantees rest on these, without a proof:</p>
            <ul>
              {TRUSTED.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ul>
          </section>
        </div>
      </aside>
    </div>
  );
}
