#!/usr/bin/env python3
"""The illustrated lesson for each ladder level: annotated syntax, what Lean accepts and
rejects, and one exercise to run next.

Lessons live in references/lessons/L1.md .. L8.md. The same file is shown in chat and
rendered as a page for the browser.

Usage:
  lesson.py list                                 levels, titles, and the exercise each ends on
  lesson.py show L1                              print the lesson (for chat)
  lesson.py render L1 [--out DIR] [--project DIR] [--open]
                                                 write every lesson page; print the one asked for
  lesson.py check [L1 ...]                       compile every example with Lean and confirm it
                                                 does what the lesson says
  lesson.py tree CODE PIECE LABEL [PIECE LABEL ...]
                                                 an aligned annotated tree for one line of code;
                                                 pieces left to right

Conventions in a lesson file:
  ```lean          compiles cleanly; blocks build on each other in order.
                   `#eval e  -- out` asserts that Lean prints `out`.
  ```lean fails    Lean rejects it; a `-- Lean says: TEXT` line names the error it reports.
                   Comment lines after that explain why.
  ```lean exercise the learner's next exercise, as it appears in assets/exercises (not compiled).
  ```tree          a code line with its pieces labelled underneath (made by `lesson.py tree`).
  ```goal          what the Lean panel shows: hypotheses, then the goal after ⊢.
  ## Run one exercise now      rendered as the call to action.
  ## Check yourself            list items; an indented `Answer:` line is hidden until clicked.
"""
import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import webbrowser
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
LESSONS = SKILL / "references" / "lessons"
HOME = Path(os.environ.get("VIBECHECK_HOME", Path.home() / ".vibecheck"))
LEVELS = [f"L{i}" for i in range(1, 9)]
FENCE = re.compile(r"^```(\w*)\s*(.*)$")
SAYS = re.compile(r"^\s*--\s*Lean says:\s*(.+?)\s*$")
EVAL = re.compile(r"^\s*#eval\s.*?\s--\s*(.+?)\s*$")


# ---------- reading lessons ----------

def lesson_file(level: str) -> Path:
    level = level.upper()
    if level not in LEVELS:
        sys.exit(f"no lesson {level}; levels are {', '.join(LEVELS)}")
    return LESSONS / f"{level}.md"


def blocks(text: str):
    """Split markdown into ('fence', lang, flags, lines, first_line_no) and ('text', lines)."""
    out, buf, fence = [], [], None
    for no, line in enumerate(text.splitlines(), 1):
        m = FENCE.match(line)
        if fence is None and m:
            if buf:
                out.append(("text", buf))
                buf = []
            fence = (m.group(1), m.group(2).strip(), [], no + 1)
        elif fence is not None and line.strip() == "```":
            out.append(("fence",) + (fence[0], fence[1], fence[2], fence[3]))
            fence = None
        elif fence is not None:
            fence[2].append(line)
        else:
            buf.append(line)
    if buf:
        out.append(("text", buf))
    return out


def title_of(text: str) -> str:
    m = re.search(r"^# (.+)$", text, re.M)
    return m.group(1).strip() if m else ""


def exercise_of(text: str) -> str:
    m = re.search(r"^## Run one exercise now\s*\n+(?:.*\n)*?\*\*(Exercise [\d.]+[^*]*)\*\*", text, re.M)
    return m.group(1).strip() if m else ""


# ---------- annotated trees ----------

def tree(code: str, pieces, fenced=False):
    """Label pieces of one line of code. pieces: [(substring, label)], left to right.
    fenced=True returns a ```tree block whose info string records each piece's columns,
    so the rendered page can colour exactly those characters."""
    cols, spans, at = [], [], 0
    for piece, label in pieces:
        i = code.find(piece, at)
        if i < 0:
            raise ValueError(f"{piece!r} not found in {code!r} after column {at}")
        cols.append((i, label))
        spans.append(f"{i}:{i + len(piece)}")
        at = i + len(piece)
    lines = [code]
    for k in range(len(cols) - 1, -1, -1):
        row = [" "] * (cols[k][0] + 1)
        for j in range(k):
            row[cols[j][0]] = "│"
        row[cols[k][0]] = "└─ " + cols[k][1]
        lines.append("".join(row).rstrip())
    if fenced:
        return "```tree spans=" + ",".join(spans) + "\n" + "\n".join(lines) + "\n```"
    return "\n".join(lines)


def spans_of(flags: str):
    m = re.search(r"spans=([\d:,]+)", flags)
    return [tuple(int(x) for x in p.split(":")) for p in m.group(1).split(",")] if m else None


def tree_columns(lines):
    """Columns of the branch marks (└) in a tree block, in left-to-right order."""
    cols = []
    for line in lines[1:]:
        i = line.find("└")
        if i >= 0:
            cols.append(i)
    return sorted(cols)


# ---------- checking against Lean ----------

def lean_cmd():
    for p in (shutil.which("lean"), str(Path.home() / ".elan" / "bin" / "lean")):
        if p and Path(p).exists():
            return p
    return None


def check(level: str):
    text = lesson_file(level).read_text()
    src, spans, problems = [], [], []
    for b in blocks(text):
        if b[0] != "fence":
            continue
        _, lang, flags, lines, md_line = b
        if lang == "tree":
            code = lines[0] if lines else ""
            cols = tree_columns(lines)
            sp = spans_of(flags)
            if sp is not None and [a for a, _ in sp] != cols:
                problems.append(f"line {md_line}: tree spans {flags!r} don't match its branches")
            for c in cols:
                if c >= len(code) or code[c] == " ":
                    problems.append(f"line {md_line}: tree branch at column {c} points at no code")
            for k, l in enumerate(lines[1:], 1):
                for c, ch in enumerate(l):
                    if ch == "│" and c not in cols:
                        problems.append(f"line {md_line + k}: a │ at column {c} leads to no branch")
            continue
        if lang != "lean":
            continue
        if "exercise" in flags.split():
            ex = "\n".join(p.read_text() for p in (SKILL / "assets" / "exercises").glob(f"{level}_*.lean"))
            for l in lines:
                if l.strip() and l.strip() not in ex:
                    problems.append(f"line {md_line}: exercise line not in the {level} exercise file: {l.strip()!r}")
            continue
        start = len(src) + 1
        src.extend(lines)
        spans.append((start, len(src), flags, lines, md_line))
        src.append("")
    lean = lean_cmd()
    if not lean:
        return {"level": level, "ok": False, "problems": ["lean is not installed"], "blocks": len(spans)}
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / f"Lesson{level}.lean"
        f.write_text("\n".join(src) + "\n")
        r = subprocess.run([lean, "--json", f.name], cwd=d, capture_output=True, text=True, timeout=300)
    msgs = []
    for line in r.stdout.splitlines():
        try:
            msgs.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    for start, end, flags, lines, md_line in spans:
        mine = [m for m in msgs if start <= m["pos"]["line"] <= end]
        errors = [m["data"] for m in mine if m["severity"] == "error"]
        where = f"line {md_line}"
        if "fails" in flags.split():
            says = next((SAYS.match(l).group(1) for l in lines if SAYS.match(l)), None)
            if not errors:
                problems.append(f"{where}: marked as failing, but Lean accepts it")
            elif says and not any(says.strip('"') in e for e in errors):
                problems.append(f"{where}: Lean's error does not mention {says!r}: {errors[0][:120]!r}")
            continue
        for e in errors:
            problems.append(f"{where}: unexpected error: {e[:160]!r}")
        for m in mine:
            if m["severity"] == "warning" and "sorry" in m["data"]:
                problems.append(f"{where}: uses sorry")
        for k, l in enumerate(lines):
            ev = EVAL.match(l)
            if not ev:
                continue
            got = [m["data"].strip() for m in mine
                   if m["severity"] == "information" and m["pos"]["line"] == start + k]
            if got != [ev.group(1)]:
                problems.append(f"line {md_line + k}: #eval prints {got!r}, the lesson says {ev.group(1)!r}")
    return {"level": level, "ok": not problems, "problems": problems, "blocks": len(spans)}


# ---------- rendering ----------

KEYWORDS = ("def theorem example by fun if then else match with do let mut for in return structure "
            "inductive where induction generalizing at import open namespace end have show from "
            "using simp simpa omega decide rfl unfold split grind intro exact apply generalize "
            "mvcgen invariants try cases").split()
TOKEN = re.compile(r'(--.*$)|("(?:[^"\\]|\\.)*")|(#\w+)|(\b\d+\b)|([A-Za-z_][\w.\']*)|(.)', re.S)


def hl(line: str) -> str:
    out = []
    for m in TOKEN.finditer(line):
        com, s, cmd, num, ident, other = m.groups()
        e = html.escape(m.group(0))
        if com:
            out.append(f'<span class="c">{e}</span>')
        elif s:
            out.append(f'<span class="s">{e}</span>')
        elif cmd:
            out.append(f'<span class="k">{e}</span>')
        elif num:
            out.append(f'<span class="n">{e}</span>')
        elif ident and ident in KEYWORDS:
            out.append(f'<span class="k">{e}</span>')
        elif ident and ident[0].isupper():
            out.append(f'<span class="t">{e}</span>')
        else:
            out.append(e)
    return "".join(out)


def inline(s: str) -> str:
    codes = []

    def keep(m):
        codes.append(m.group(1))
        return f"\x00{len(codes) - 1}\x00"
    s = re.sub(r"`([^`]+)`", keep, s)
    s = html.escape(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)\*(?!\w)", r"<em>\1</em>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
    return re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{html.escape(codes[int(m.group(1))])}</code>", s)


def render_tree(lines, flags="", checked=False):
    code = lines[0] if lines else ""
    cols = tree_columns(lines)
    segs = spans_of(flags)
    if segs is None:
        segs = [(c, (cols[i + 1] if i + 1 < len(cols) else len(code))) for i, c in enumerate(cols)]
        segs = [(a, a + len(code[a:b].rstrip())) for a, b in segs]
    html_code, pos = "", 0
    for i, (a, b) in enumerate(segs):
        html_code += html.escape(code[pos:a])
        html_code += f'<span class="pc p{i % 6}" data-i="{i}">{html.escape(code[a:b])}</span>'
        pos = b
    html_code += html.escape(code[pos:])
    rows = []
    for line in lines[1:]:
        k = line.find("└")
        if k < 0:
            rows.append(html.escape(line))
            continue
        i = cols.index(k)
        label = line[k + 3:] if line[k:k + 3] == "└─ " else line[k + 1:]
        rows.append(html.escape(line[:k]) + f'<span class="br p{i % 6}">└─</span> '
                    f'<span class="lb p{i % 6}" data-i="{i}">{inline(label)}</span>')
    pre = f'<pre><span class="code">{html_code}</span>\n' + "\n".join(rows) + "</pre>"
    tag = '<div class="tag">✓ checked by Lean</div>' if checked else ""
    return f'<div class="tree{" ok" if checked else ""}">{tag}{pre}</div>'


def render_goal(lines):
    rows = []
    for l in lines:
        if l.startswith("case "):
            rows.append(f'<div class="case">{html.escape(l)}</div>')
        elif l.startswith("⊢"):
            rows.append(f'<div class="turnstile">{html.escape(l)}</div>')
        else:
            rows.append(f'<div class="hyp">{html.escape(l)}</div>')
    return '<div class="goal"><div class="goal-h">Lean panel</div>' + "".join(rows) + "</div>"


def render_lean(lines, flags):
    if "fails" in flags.split():
        code, says, why, seen = [], None, [], False
        for l in lines:
            m = SAYS.match(l)
            if m:
                says, seen = m.group(1).strip('"'), True
            elif seen and l.strip().startswith("--"):
                why.append(l.strip()[2:].strip())
            else:
                code.append(l)
        while code and not code[-1].strip():
            code.pop()
        body = "\n".join(hl(l) for l in code)
        says_html = f'<div class="says"><b>Lean says:</b> {html.escape(says)}</div>' if says else ""
        why_html = f"<p>{inline(' '.join(why))}</p>" if why else ""
        return (f'<div class="card bad"><div class="tag">✗ Lean rejects this</div>'
                f"<pre>{body}</pre>{says_html}{why_html}</div>")
    body = "\n".join(hl(l) for l in lines)
    if "exercise" in flags.split():
        return f'<div class="card you"><div class="tag">✎ your turn</div><pre>{body}</pre></div>'
    return f'<div class="card ok"><div class="tag">✓ checked by Lean</div><pre>{body}</pre></div>'


def list_items(lines):
    items = []
    for l in lines:
        m = re.match(r"^\s*(?:[-*]|\d+\.)\s+(.*)$", l)
        if m and not l.startswith("   "):
            items.append([m.group(1)])
        elif items:
            items[-1].append(l.strip())
    return items


def render_text(lines, section):
    out, i = [], 0
    while i < len(lines):
        l = lines[i]
        if not l.strip():
            i += 1
            continue
        if l.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            head = "".join(f"<th>{inline(c)}</th>" for c in rows[0])
            body = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows[1:])
            out.append(f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>")
            continue
        if re.match(r"^(?:[-*]|\d+\.)\s", l):
            chunk = []
            while i < len(lines) and (re.match(r"^(?:[-*]|\d+\.)\s", lines[i]) or lines[i].startswith("  ")):
                chunk.append(lines[i])
                i += 1
            tag = "ol" if re.match(r"^\d+\.", l) else "ul"
            lis = []
            for item in list_items(chunk):
                main = [x for x in item if not re.match(r"^\*?Answer:", x)]
                ans = [re.sub(r"^\*?Answer:\*?\s*", "", x) for x in item if re.match(r"^\*?Answer:", x)]
                h = inline(" ".join(main))
                if ans:
                    h += f'<details><summary>Answer</summary>{inline(" ".join(ans))}</details>'
                lis.append(f"<li>{h}</li>")
            out.append(f"<{tag}>{''.join(lis)}</{tag}>")
            continue
        if l.startswith(">"):
            q = []
            while i < len(lines) and lines[i].startswith(">"):
                q.append(lines[i][1:].strip())
                i += 1
            out.append(f'<p class="lede">{inline(" ".join(q))}</p>')
            continue
        if l.startswith("### "):
            out.append(f"<h3>{inline(l[4:])}</h3>")
            i += 1
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not re.match(r"^(\||>|#|(?:[-*]|\d+\.)\s)", lines[i]):
            para.append(lines[i].strip())
            i += 1
        out.append(f"<p>{inline(' '.join(para))}</p>")
    return "".join(out)


def load_profile():
    p = HOME / "profile.json"
    try:
        return json.loads(p.read_text()) if p.exists() else {}
    except json.JSONDecodeError:
        return {}


def render_page(level: str, profile) -> str:
    text = lesson_file(level).read_text()
    title = title_of(text)
    done = set(profile.get("topics", {}))
    current = profile.get("project_level") if profile.get("learning_track") == "api-check" else None
    chips = []
    for lv in LEVELS:
        cls = "here" if lv == level else ("done" if lv in done else "")
        mark = "✓ " if lv in done else ""
        chips.append(f'<a class="chip {cls}" href="{lv}.html">{mark}{lv}</a>')
    body, section_open = [], False
    bl = [b for b in blocks(text) if b[0] == "fence" or any(l.strip() for l in b[1])]
    for n, b in enumerate(bl):
        if b[0] == "fence":
            _, lang, flags, lines, _ = b
            nxt = bl[n + 1] if n + 1 < len(bl) else None
            merged = (lang == "lean" and not flags and len(lines) == 1 and nxt and nxt[0] == "fence"
                      and nxt[1] == "tree" and nxt[3] and nxt[3][0] == lines[0])
            prev = bl[n - 1] if n else None
            if merged:
                continue
            if lang == "lean":
                body.append(render_lean(lines, flags))
            elif lang == "tree":
                checked = (prev and prev[0] == "fence" and prev[1] == "lean" and not prev[2]
                           and len(prev[3]) == 1 and prev[3][0] == lines[0])
                body.append(render_tree(lines, flags, checked))
            elif lang == "goal":
                body.append(render_goal(lines))
            else:
                body.append(f'<pre class="plain">{html.escape(chr(10).join(lines))}</pre>')
            continue
        chunk = []
        for l in b[1]:
            if l.startswith("# "):
                continue
            if l.startswith("## "):
                if chunk:
                    body.append(render_text(chunk, None))
                    chunk = []
                if section_open:
                    body.append("</section>")
                name = l[3:].strip()
                cls = "cta" if name.lower().startswith("run one exercise") else ""
                body.append(f'<section class="{cls}"><h2>{inline(name)}</h2>')
                section_open = True
            else:
                chunk.append(l)
        if chunk:
            body.append(render_text(chunk, None))
    if section_open:
        body.append("</section>")
    track = (f'<p class="track">You are on the API checker track at {html.escape(current)}. '
             "Each lesson's last section says how it applies there.</p>") if current else ""
    i = LEVELS.index(level)
    prev = f'<a href="{LEVELS[i - 1]}.html">← {LEVELS[i - 1]}</a>' if i else "<span></span>"
    nxt = f'<a href="{LEVELS[i + 1]}.html">{LEVELS[i + 1]} →</a>' if i + 1 < len(LEVELS) else "<span></span>"
    return PAGE.format(title=html.escape(title), chips="".join(chips), track=track,
                       body="\n".join(body), prev=prev, next=nxt)


PAGE = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
 :root {{ --ink:#1d1d1f; --mute:#6e6e73; --line:#e5e5ea; --soft:#f5f5f7; --ok:#1f7a3a; --bad:#b3261e;
          --p0:#0a66c2; --p1:#a2390a; --p2:#6b3fa0; --p3:#0f7b6c; --p4:#b5179e; --p5:#8a6d00; }}
 * {{ box-sizing: border-box; }}
 body {{ font: 17px/1.6 -apple-system, system-ui, sans-serif; color: var(--ink); margin: 0; background: #fff; }}
 main {{ max-width: 820px; margin: 0 auto; padding: 24px 22px 80px; }}
 nav {{ display: flex; gap: 6px; flex-wrap: wrap; margin: 8px 0 28px; }}
 .chip {{ font: 13px ui-monospace, Menlo, monospace; padding: 4px 10px; border-radius: 999px; border: 1px solid var(--line);
          color: var(--mute); text-decoration: none; }}
 .chip.done {{ color: var(--ok); border-color: #b7dfc3; }}
 .chip.here {{ background: var(--ink); color: #fff; border-color: var(--ink); }}
 h1 {{ font-size: 32px; line-height: 1.2; margin: 0 0 8px; }}
 h2 {{ font-size: 21px; margin: 40px 0 10px; }}
 h3 {{ font-size: 17px; margin: 24px 0 6px; }}
 .lede {{ font-size: 19px; color: #3a3a3c; margin: 0 0 8px; }}
 .track {{ color: var(--mute); font-size: 15px; }}
 code {{ font: 0.88em ui-monospace, Menlo, monospace; background: var(--soft); padding: 1px 5px; border-radius: 4px; }}
 pre {{ font: 14.5px/1.55 ui-monospace, Menlo, monospace; margin: 0; padding: 14px 16px; overflow-x: auto; }}
 .card {{ border: 1px solid var(--line); border-radius: 10px; margin: 14px 0; overflow: hidden; background: #fbfbfd; }}
 .card .tag {{ font: 12px ui-monospace, Menlo, monospace; padding: 6px 14px; border-bottom: 1px solid var(--line); color: var(--ok); }}
 .card.bad {{ border-color: #f1c4c0; background: #fffafa; }}
 .card.bad .tag {{ color: var(--bad); border-color: #f1c4c0; }}
 .card p {{ margin: 0; padding: 0 16px 14px; font-size: 15.5px; }}
 .card.you {{ border-color: #9cc0f5; }} .card.you .tag {{ color: var(--p0); border-color: #cfe0fb; }}
 .says {{ margin: 0 16px 12px; padding: 8px 12px; background: #fdecea; border-radius: 6px; font: 13.5px ui-monospace, Menlo, monospace; color: var(--bad); }}
 .says b {{ font-family: -apple-system, system-ui, sans-serif; }}
 .k {{ color: #9b2393; font-weight: 600; }} .c {{ color: #8e8e93; font-style: italic; }}
 .s {{ color: #c41a16; }} .n {{ color: #1c00cf; }} .t {{ color: #0b6e99; }}
 .tree {{ background: #fbfbfd; border: 1px solid var(--line); border-radius: 10px; margin: 14px 0; color: #aeaeb2; overflow: hidden; }}
 .tree .tag {{ font: 12px ui-monospace, Menlo, monospace; padding: 6px 14px; border-bottom: 1px solid var(--line); color: var(--ok); }}
 .tree .code {{ color: var(--ink); font-weight: 600; }}
 .pc {{ border-bottom: 2px solid currentColor; padding-bottom: 1px; transition: background .15s; }}
 .lb {{ font-family: -apple-system, system-ui, sans-serif; font-size: 15px; }}
 .lb code {{ font-size: 13px; }}
 .p0 {{ color: var(--p0); }} .p1 {{ color: var(--p1); }} .p2 {{ color: var(--p2); }}
 .p3 {{ color: var(--p3); }} .p4 {{ color: var(--p4); }} .p5 {{ color: var(--p5); }}
 .lit {{ background: #fff3bf; border-radius: 3px; }}
 .goal {{ background: #1e1f22; color: #e6e6e6; border-radius: 10px; margin: 14px 0; padding: 0 0 12px;
          font: 14.5px/1.6 ui-monospace, Menlo, monospace; }}
 .goal-h {{ font: 12px -apple-system, system-ui, sans-serif; color: #9a9aa0; padding: 8px 16px; border-bottom: 1px solid #333; margin-bottom: 8px; }}
 .goal div.hyp, .goal div.turnstile, .goal div.case {{ padding: 0 16px; white-space: pre; }}
 .goal .case {{ color: #9a9aa0; }} .goal .turnstile {{ color: #ffd479; font-weight: 600; }}
 .plain {{ background: var(--soft); border-radius: 10px; margin: 14px 0; }}
 table {{ border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 15.5px; }}
 th, td {{ text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }}
 th {{ font-size: 13px; color: var(--mute); font-weight: 600; }}
 section.cta {{ background: #f0f6ff; border: 1px solid #cfe0fb; border-radius: 14px; padding: 4px 22px 14px; margin-top: 44px; }}
 section.cta h2 {{ margin-top: 18px; }}
 section.cta .card {{ background: #fff; }}
 details {{ margin: 6px 0 2px; color: #3a3a3c; }} summary {{ cursor: pointer; color: var(--p0); font-size: 15px; }}
 li {{ margin: 6px 0; }}
 footer {{ display: flex; justify-content: space-between; margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--line); }}
 footer a {{ color: var(--p0); text-decoration: none; }}
</style></head><body><main>
<nav>{chips}</nav>
<h1>{title}</h1>
{track}
{body}
<footer>{prev}{next}</footer>
</main>
<script>
 document.querySelectorAll('.tree').forEach(t => t.querySelectorAll('[data-i]').forEach(el => {{
   const mates = () => t.querySelectorAll('[data-i="' + el.dataset.i + '"]');
   el.addEventListener('mouseenter', () => mates().forEach(m => m.classList.add('lit')));
   el.addEventListener('mouseleave', () => mates().forEach(m => m.classList.remove('lit')));
 }}));
</script>
</body></html>
"""


def render(level: str, out_dir: Path, profile) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    for lv in LEVELS:
        if lesson_file(lv).exists():
            (out_dir / f"{lv}.html").write_text(render_page(lv, profile))
    return out_dir / f"{level}.html"


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    s = sub.add_parser("show"); s.add_argument("level")
    r = sub.add_parser("render"); r.add_argument("level")
    r.add_argument("--out"); r.add_argument("--project"); r.add_argument("--open", action="store_true")
    c = sub.add_parser("check"); c.add_argument("levels", nargs="*")
    t = sub.add_parser("tree"); t.add_argument("code"); t.add_argument("pieces", nargs="+")
    t.add_argument("--fence", action="store_true", help="print a ```tree block with piece spans, for lesson files")
    a = ap.parse_args()

    if a.cmd == "list":
        for lv in LEVELS:
            f = lesson_file(lv)
            if f.exists():
                text = f.read_text()
                print(f"{lv}  {title_of(text)}\n    ends on: {exercise_of(text) or '-'}")
        return 0
    if a.cmd == "show":
        print(lesson_file(a.level).read_text())
        return 0
    if a.cmd == "tree":
        if len(a.pieces) % 2:
            sys.exit("give pieces and labels in pairs: PIECE LABEL [PIECE LABEL ...]")
        print(tree(a.code, list(zip(a.pieces[::2], a.pieces[1::2])), fenced=a.fence))
        return 0
    if a.cmd == "render":
        if a.out:
            out = Path(a.out).expanduser()
        elif a.project:
            out = Path(a.project).expanduser() / ".vibecheck" / "lessons"
        else:
            out = HOME / "lessons"
        page = render(a.level.upper(), out, load_profile())
        if a.open:
            webbrowser.open(page.resolve().as_uri())
        print(json.dumps({"lesson": str(lesson_file(a.level)), "page": str(page), "opened": a.open}))
        return 0
    if a.cmd == "check":
        levels = [x.upper() for x in a.levels] or [lv for lv in LEVELS if lesson_file(lv).exists()]
        ok = True
        for lv in levels:
            res = check(lv)
            ok &= res["ok"]
            print(f"{lv}: {'ok' if res['ok'] else 'FAIL'} ({res['blocks']} Lean blocks)")
            for p in res["problems"]:
                print(f"   {p}")
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
