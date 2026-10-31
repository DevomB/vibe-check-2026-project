#!/usr/bin/env python3
"""Print the vibecheck-lean map: the four rungs, what each involves, and where this
person is on it (from their profile), followed by the opening question.

Usage: welcome.py [--no-question] [--width 78]

Show the output to the user exactly as printed, inside a code block, so the boxes
stay aligned. Read-only.
"""
import json
import os
import sys
from datetime import date
from pathlib import Path

HOME = Path(os.environ.get("VIBECHECK_HOME", Path.home() / ".vibecheck"))
W = 21          # inner width of each column box
GAP = "    "    # between columns; arrows are drawn here

LEVELS = ["L1 programs, #eval", "L2 facts for all x", "L3 branches", "L4 induction",
          "L5 fast = simple", "L6 loops", "L7 invariant types", "L8 a compiler"]
API_LEVELS = ["L1 API status, #eval", "L2 request budgets", "L3 error handling", "L4 retry plans",
              "L5 fast = reference", "L6 response summaries", "L7 valid config", "L8 command compiler"]

COLUMNS = [
    ("learn", "1  LEARN LEAN", "new to it, or rusty", None),
    ("build-app", "2  BUILD AN APP", "make it, prove it", [
        " your idea, or a", " starter: undo,", " crdt, rle", "", " property in English",
        " spec in Lean", " prove it", " run it, audit it"]),
    ("spec-existing", "3  SPEC MY PROJECT", "code you already have", [
        " repo scanned", " route picked:", "  lean, port+prove,", "  rust, protocol",
        " spec interview", " prove (+diff test)", " audit it", ""]),
]


def load():
    p = HOME / "profile.json"
    return json.loads(p.read_text()) if p.exists() else None


def pad(s, w=W):
    return s[:w].ljust(w)


def learn_rows(prof):
    topics = (prof or {}).get("topics", {})
    rows, nxt = [], None
    levels = API_LEVELS if (prof or {}).get("learning_track") == "api-check" else LEVELS
    for i, lv in enumerate(levels, 1):
        key = f"L{i}"
        if key in topics:
            rows.append("✓ " + lv)
        elif nxt is None and topics:
            nxt = key
            rows.append("> " + lv)
        else:
            rows.append("  " + lv)
    return rows


def render(prof):
    rung = (prof or {}).get("rung")
    out = []
    title = "VIBECHECK · LEAN"
    right = "your map" if prof else "where would you like to start?"
    total = 3 * (W + 2) + 2 * len(GAP)
    out.append("  " + title + right.rjust(total - len(title)))
    out.append("  " + "─" * total)

    # "you are here" marker row
    marks = []
    for key, *_ in COLUMNS:
        marks.append(pad("  ▼ you are here" if key == rung else "", W + 2))
    if rung in [c[0] for c in COLUMNS]:
        out.append("  " + GAP.join(marks).rstrip())
    else:
        out.append("")

    out.append("  " + GAP.join(pad(" " + c[1], W + 2) for c in COLUMNS).rstrip())
    out.append("  " + GAP.join(pad(" " + c[2], W + 2) for c in COLUMNS).rstrip())
    out.append("  " + GAP.join("┌" + "─" * W + "┐" for _ in COLUMNS))
    bodies = [learn_rows(prof)] + [c[3] for c in COLUMNS[1:]]
    for r in range(len(LEVELS)):
        cells = ["│" + pad(b[r] if r < len(b) else "") + "│" for b in bodies]
        gap = " ──▶" if r == 3 else GAP
        out.append("  " + cells[0] + gap + cells[1] + gap + cells[2])
    out.append("  " + GAP.join("└" + "─" * W + "┘" for _ in COLUMNS))
    out.append("  " + "after L3 you can join a team    after L5 you can spec most business logic")
    out.append("")

    # refresh bar under everything
    due = []
    if prof:
        t = date.today().isoformat()
        due = [k for k, v in prof.get("topics", {}).items() if v.get("next_due", "9999") <= t]
    label = " 4  KEEP ME SHARP · 10-20 min spaced refreshers"
    if rung == "refresh":
        label += "   ◀ you are here"
    out.append("  ┌" + "─" * (total - 2) + "┐")
    out.append("  │" + pad(label, total - 2) + "│")
    if due:
        out.append("  │" + pad(f"    due today: {', '.join(sorted(due)[:6])}", total - 2) + "│")
    out.append("  └" + "─" * (total - 2) + "┘")

    if prof:
        if prof.get("learning_track") == "api-check":
            out.append("  your build: API checker · " + prof.get("project_level", "L1") + " in progress")
        last = prof.get("last_session")
        bits = []
        if last:
            days = (date.today() - date.fromisoformat(last)).days
            bits.append(f"last session {days} day{'s' if days != 1 else ''} ago")
        if prof.get("weak_spots"):
            bits.append("worth revisiting: " + ", ".join(prof["weak_spots"][:3]))
        if bits:
            out.append("  " + " · ".join(bits))
    return "\n".join(out)


QUESTION_NEW = """Where would you like to start? (You can switch any time.)

  1. Learn Lean: never used it, or it didn't stick. Short exercises.
  2. Build an app in Lean: make something new and prove it works.
  3. Spec my existing project: prove what your code must and must not do.
  4. Keep me sharp: short, regular refreshers on what you've learned.

Reply with a number. Not sure? Reply "?" and I'll ask two quick questions.
Want a closer look first? Reply "?2" (or any number)."""

NAMES = {"learn": "Learn Lean", "build-app": "Build an app in Lean",
         "spec-existing": "Spec my existing project", "refresh": "Keep me sharp"}


def main():
    prof = load()
    print(render(prof))
    if "--no-question" in sys.argv:
        return
    print()
    if prof and prof.get("rung") in NAMES:
        print(f"Still on \"{NAMES[prof['rung']]}\" today? Reply \"yes\", or a number to switch:\n")
        print("\n".join(QUESTION_NEW.splitlines()[2:6]))
    else:
        print(QUESTION_NEW)


if __name__ == "__main__":
    main()
