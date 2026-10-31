#!/usr/bin/env python3
"""Get the learner's workspace on screen: editor with the Lean extension, the right file,
a start page for their rung, and Loogle in the browser.

Usage:
  launch.py RUNG [--project DIR] [--file REL] [--also FILE ...] [--level L3]
                 [--install-extension] [--no-editor] [--no-browser] [--dry-run]

RUNG is one of: spec-existing, build-app, learn, refresh.

--level copies that exercise into DIR/Learn/ if it isn't there yet and opens it. On the
learn rung, when the profile lists Python, TypeScript or JavaScript, the language bridge is
copied to DIR/Learn/Bridge.lean and opened alongside. --also opens extra files.
On the learn rung the level's illustrated lesson (references/lessons/L<n>.md) is rendered to
DIR/.vibecheck/lessons/ and, in editor mode, opened in the browser; the JSON names both files.
--dry-run touches nothing (no copies, no start page, no windows) and says so in the JSON. The Lean extension is only installed with --install-extension: without
it, a missing extension is reported (`"extension": "missing"`) so you can ask first.
Prints a JSON summary of what it did.
"""
import argparse
import html
import json
import os
import shutil
import subprocess
import sys
import webbrowser
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lesson  # noqa: E402

SKILL = Path(__file__).resolve().parent.parent
HOME = Path(os.environ.get("VIBECHECK_HOME", Path.home() / ".vibecheck"))
MAC_CODE = [
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
    str(Path.home() / "Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"),
]
LOOGLE = "https://loogle.lean-lang.org/"

LINKS = {
    "loogle": ("Loogle", LOOGLE, "Search lemmas by name or shape, e.g. List.length (_ ++ _)"),
    "fpil": ("Functional Programming in Lean", "https://lean-lang.org/functional_programming_in_lean/",
             "Lean as a programming language"),
    "tpil": ("Theorem Proving in Lean 4", "https://lean-lang.org/theorem_proving_in_lean4/",
             "How proofs and tactics work"),
    "tactics": ("Tactic reference", "https://lean-lang.org/doc/reference/latest/Tactic-Proofs/Tactic-Reference/",
                "Every tactic, with examples"),
    "mvcgen": ("Verifying imperative programs (mvcgen)", "https://lean-lang.org/doc/tutorials/4.34.0/mvcgen/",
               "Loops, let mut, invariants"),
    "nng": ("Natural Number Game", "https://adam.math.hhu.de/#/g/leanprover-community/nng4",
            "Tactic practice in the browser"),
    "live": ("Lean in the browser", "https://live.lean-lang.org", "Try a snippet without a project"),
    "releases": ("Lean release notes", "https://lean-lang.org/doc/reference/latest/releases/",
                 "What changed since you last looked"),
    "zulip": ("Lean Zulip", "https://leanprover.zulipchat.com", "Ask humans; #new members is friendly"),
    "hax": ("hax Lean quick start", "https://hax.cryspen.com/manual/lean/quick_start/", "Rust to Lean"),
    "veil": ("Veil", "https://github.com/verse-lab/veil", "Distributed protocols in Lean"),
}

RUNGS = {
    "learn": {
        "title": "Learning Lean",
        "steps": [
            "Open the exercise in VS Code; the infoview on the right shows the goal.",
            "Read the worked example first, clicking on each line to watch the goal change.",
            "Replace each sorry. Ask Claude for a hint, not the answer, when stuck.",
            "A level is done when the file shows no errors and no sorry warnings.",
        ],
        "links": ["loogle", "fpil", "tpil", "tactics", "nng"],
        "ask": ["give me a hint for this exercise", "explain this goal", "I finished the level, what's next?"],
    },
    "build-app": {
        "title": "Building a verified app",
        "steps": [
            "Write the headline property in one English sentence.",
            "Spec.lean: one def per property, each with a doc comment. Lock it with audit.py --lock.",
            "Impl.lean: the code. Proofs.lean: one theorem per property. Main.lean: the I/O.",
            "Run the audit before every demo.",
        ],
        "links": ["loogle", "fpil", "mvcgen", "tactics", "zulip"],
        "ask": ["help me write the spec for my app", "prove the next property",
                "add a command-line interface around the verified core", "run the audit"],
    },
    "spec-existing": {
        "title": "Specifying an existing project",
        "steps": [
            "Name the module or function that carries the risk.",
            "Answer the spec interview: never / always possible / bounds / invariants / roundtrips.",
            "Review the properties in English, then in Lean, then lock them.",
            "Prove, differential-test if it is a port, audit.",
        ],
        "links": ["loogle", "tactics", "mvcgen", "hax", "veil", "zulip"],
        "ask": ["interview me for the spec", "which functions should we verify first?",
                "prove the headline property", "write the differential test"],
    },
    "refresh": {
        "title": "Refresher session",
        "steps": [
            "Warm up: today's drill is open in VS Code. Solve it without looking anything up.",
            "Then one new idea, tried on a small example.",
            "Claude records how it went and schedules the next review.",
        ],
        "links": ["loogle", "releases", "tactics", "zulip"],
        "ask": ["what's due today?", "give me a harder drill", "what's new in Lean since my last session?"],
    },
}

CHEATS = [
    ("grind", "SMT-style automation; try it first"),
    ("simp [f]", "unfold f and simplify"),
    ("omega", "linear arithmetic over Nat and Int"),
    ("intro x h", "move ∀ and → into hypotheses"),
    ("split / split at h", "case on an if or match"),
    ("induction xs generalizing acc", "induction with a changing argument"),
    ("exact?", "search the library for a closing lemma"),
    ("decide / rfl", "prove closed facts by computation"),
    ("have h : P := by …", "prove a stepping stone"),
]


def code_cli():
    for name in ("code", "cursor", "codium"):
        p = shutil.which(name)
        if p:
            return p
    for p in MAC_CODE:
        if Path(p).exists():
            return p
    return None


def load_profile():
    p = HOME / "profile.json"
    return json.loads(p.read_text()) if p.exists() else {}


def lib_of(project: Path):
    toml = project / "lakefile.toml"
    if toml.exists():
        import re
        m = re.search(r'\[\[lean_lib\]\]\s*\n\s*name\s*=\s*"([^"]+)"', toml.read_text())
        if m:
            return m.group(1)
    return None


def default_file(rung, project: Path):
    lib = lib_of(project) if project else None
    if not lib:
        return None
    return {"build-app": f"{lib}/Spec.lean", "spec-existing": f"{lib}/Spec.lean",
            "learn": None, "refresh": None}[rung]


def start_page(rung, profile, project, opened_file, mode="editor"):
    r = RUNGS[rung]
    e = html.escape
    if rung == "learn":
        check = f"cd {project}\nlake env lean {opened_file or 'Learn/<file>.lean'}   # done = no errors, no sorry"
    elif rung == "refresh":
        check = f"lean {project / opened_file if project and opened_file else '<drill>.lean'}   # done = no errors, no sorry"
    else:
        check = f"lake build\npython3 {SKILL}/scripts/audit.py {project or '.'} --report"
    due = []
    for topic, rec in profile.get("topics", {}).items():
        if rec.get("next_due", "9999") <= date.today().isoformat():
            due.append(topic)
    instructions = r["steps"] if mode == "editor" else [
        "Paste Lean code into the conversation. The assistant runs it and returns the compiler output.",
        "Successful declarations remain available to later snippets in this chat session.",
        "Read each goal before choosing your next proof step. Ask for a hint when stuck.",
        "A checked snippet is not a project audit. Complete the exercise before recording a level.",
    ]
    steps = "".join(f"<li>{e(s)}</li>" for s in instructions)
    links = "".join(f'<li><a href="{e(LINKS[k][1])}">{e(LINKS[k][0])}</a> <span>{e(LINKS[k][2])}</span></li>'
                    for k in r["links"])
    asks = "".join(f"<li><code>{e(a)}</code></li>" for a in r["ask"])
    cheats = "".join(f"<tr><td><code>{e(t)}</code></td><td>{e(d)}</td></tr>" for t, d in CHEATS)
    facts = []
    if profile.get("goal"):
        facts.append(f"Goal: {e(profile['goal'])}")
    if profile.get("learning_track") == "api-check":
        facts.append(f"Build an API checker · {e(profile.get('project_level', 'L1'))}")
    if project:
        facts.append(f"Project: <code>{e(str(project))}</code>")
    if opened_file:
        facts.append(f"Open in the editor: <code>{e(opened_file)}</code>")
    if profile.get("weak_spots"):
        facts.append("Worth revisiting: " + e(", ".join(profile["weak_spots"])))
    if due:
        facts.append("Due for review today: " + e(", ".join(sorted(due))))
    if rung == "learn" and opened_file:
        import re as _re
        m = _re.search(r"L[1-8]", opened_file) if "Learn/L" in opened_file else None
        lv = m.group(0) if m else profile.get("project_level")
        if lv:
            facts.append(f'Today\'s lesson: <a href="lessons/{e(lv)}.html">{e(lv)}, illustrated</a>')
    facts_html = "".join(f"<li>{f}</li>" for f in facts)
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>vibecheck-lean: {e(r['title'])}</title>
<style>
 body {{ font: 16px/1.5 -apple-system, system-ui, sans-serif; max-width: 860px; margin: 40px auto; padding: 0 20px; color: #1d1d1f; }}
 h1 {{ font-size: 28px; margin-bottom: 4px; }} h2 {{ font-size: 18px; margin-top: 32px; }}
 .sub {{ color: #6e6e73; margin-top: 0; }}
 form {{ display: flex; gap: 8px; margin: 16px 0 8px; }}
 input[type=text] {{ flex: 1; font: 15px ui-monospace, Menlo, monospace; padding: 10px 12px; border: 1px solid #c7c7cc; border-radius: 8px; }}
 button {{ padding: 10px 16px; border: 0; border-radius: 8px; background: #1d1d1f; color: #fff; font-size: 15px; cursor: pointer; }}
 code {{ font: 14px ui-monospace, Menlo, monospace; background: #f2f2f7; padding: 1px 5px; border-radius: 4px; }}
 pre {{ background: #f2f2f7; padding: 12px; border-radius: 8px; overflow-x: auto; }}
 li span {{ color: #6e6e73; }} li {{ margin: 4px 0; }}
 table {{ border-collapse: collapse; width: 100%; }} td {{ padding: 6px 8px; border-bottom: 1px solid #e5e5ea; vertical-align: top; }}
 .hint {{ color: #6e6e73; font-size: 14px; }}
</style></head><body>
<h1>{e(r['title'])}</h1>
<p class="sub">vibecheck-lean · {date.today().isoformat()}</p>
<ul>{facts_html}</ul>

<h2>Search Lean's library</h2>
<form action="{LOOGLE}" method="get" target="_blank">
 <input type="text" name="q" placeholder="List.length (_ ++ _)   or   |- _ + 0 = _   or   &quot;append&quot;" autofocus>
 <button type="submit">Loogle</button>
</form>
<p class="hint">Search by constant name, by a pattern with <code>_</code> holes, or by the conclusion with <code>|-</code>. Inside a proof, <code>exact?</code> does the same search for the current goal.</p>

<h2>What to do now</h2>
<ol>{steps}</ol>

<h2>Things to ask Claude</h2>
<ul>{asks}</ul>

<h2>Tactics to reach for</h2>
<table>{cheats}</table>

<h2>Check your work</h2>
<pre>{e(check)}</pre>

<h2>Read more</h2>
<ul>{links}</ul>
</body></html>
"""


def open_url(url, dry):
    if dry:
        return True
    if "microsoft" in os.uname().release.lower() and shutil.which("wslview"):
        return subprocess.run(["wslview", url]).returncode == 0
    return webbrowser.open(url)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("rung", choices=list(RUNGS))
    ap.add_argument("--project")
    ap.add_argument("--file")
    ap.add_argument("--also", action="append", default=[])
    ap.add_argument("--level")
    ap.add_argument("--track", choices=("api-check", "exercises"), help="grow a useful project or use standalone exercises")
    ap.add_argument("--install-extension", action="store_true")
    ap.add_argument("--no-editor", action="store_true")
    ap.add_argument("--no-browser", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--mode", choices=("chat", "editor"), help="defaults to the saved workspace preference")
    a = ap.parse_args()

    out = {"rung": a.rung, "dry_run": a.dry_run}
    project = Path(a.project).expanduser().resolve() if a.project else None
    target = a.file
    profile = load_profile()
    track = a.track or profile.get("learning_track", "exercises")

    if a.rung == "learn" and track == "api-check":
        if not project:
            sys.exit("the api-check track needs --project")
        src = SKILL / "assets" / "project-ladder" / "ApiCheck.lean"
        dst = project / "Learn" / src.name
        if not dst.exists() and not a.dry_run:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, dst)
        target = f"Learn/{src.name}"
        out["exercise"] = str(dst)
        out["track"] = track
    elif a.level:
        if not project:
            sys.exit("--level needs --project (the playground or team project)")
        src = next((p for p in (SKILL / "assets" / "exercises").glob(f"{a.level}_*.lean")), None)
        if not src:
            sys.exit(f"no exercise named {a.level}_*.lean")
        dst = project / "Learn" / src.name
        if not dst.exists() and not a.dry_run:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, dst)
        out["exercise"] = str(dst)
        target = f"Learn/{src.name}"
    mode = a.mode or profile.get("workspace_mode", "editor")
    out["mode"] = mode

    # the illustrated lesson for this level
    level = (a.level or (profile.get("project_level", "L1") if track == "api-check" else None))
    lesson_page = None
    if a.rung == "learn" and level and level.upper() in lesson.LEVELS:
        level = level.upper()
        out["lesson"] = str(lesson.lesson_file(level))
        lesson_dir = (project / ".vibecheck" / "lessons") if project else HOME / "lessons"
        lesson_page = lesson_dir / f"{level}.html"
        if not a.dry_run:
            lesson.render(level, lesson_dir, profile)
        out["lesson_page"] = str(lesson_page)
    extra = [Path(x).expanduser() for x in a.also]
    langs = {l.lower() for l in profile.get("languages", [])}
    if a.rung == "learn" and project and langs & {"python", "typescript", "javascript", "ts", "js"}:
        bridge = project / "Learn" / "Bridge.lean"
        if not bridge.exists() and not a.dry_run:
            bridge.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(SKILL / "assets" / "bridge" / "Bridge.lean", bridge)
        out["bridge"] = str(bridge)
        extra.append(bridge)
    # a loose file (drill) opens with its folder, so the editor has a workspace
    if not project and target:
        tp = Path(target).expanduser().resolve()
        project, target = tp.parent, tp.name
    if not target and project:
        target = default_file(a.rung, project)

    # editor and extension
    cli = code_cli() if mode == "editor" else None
    out["editor"] = cli
    if cli:
        exts = subprocess.run([cli, "--list-extensions"], capture_output=True, text=True).stdout.lower()
        if "leanprover.lean4" in exts:
            out["extension"] = "installed"
        elif a.install_extension:
            if not a.dry_run:
                subprocess.run([cli, "--install-extension", "leanprover.lean4"], capture_output=True)
            out["extension"] = "installed-now"
        else:
            out["extension"] = "missing"
    else:
        out["extension"] = "not-required" if mode == "chat" else "no-editor"

    # start page
    page = (project / ".vibecheck" if project else HOME) / "start.html"
    if not a.dry_run:
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text(start_page(a.rung, profile, project, target, mode))
    out["start_page"] = str(page)

    # open things
    if cli and not a.no_editor and out["extension"] != "missing" and (project or target):
        args = [cli]
        if project:
            args.append(str(project))
        if target:
            args.append(str((project / target) if project else Path(target).expanduser()))
        args += [str(x) for x in extra]
        if not a.dry_run:
            subprocess.run(args)
        out["opened_editor"] = args[1:]
    if not a.no_browser and mode == "editor":
        first = lesson_page or page
        out["opened_browser"] = [first.as_uri(), LOOGLE]
        open_url(first.as_uri(), a.dry_run)
        open_url(LOOGLE, a.dry_run)
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
