#!/usr/bin/env python3
"""Judge-ready proof audit for a Lean project.

Checks, in order:
  1. `lake build` succeeds with no `sorry` warnings.
  2. No cheat constructs in the sources (sorry, axiom, native_decide, ...), outside
     the Learn/ and Scratch/ folders. `admit` is caught by step 4 (it leaves sorryAx).
  3. Spec files are unchanged since the humans locked them (`--lock`).
  4. Every `Spec.*` property has a theorem proving it, and every project theorem
     rests only on Lean's three standard axioms.

Usage:
  audit.py [PROJECT_DIR] [--lib NAME] [--lock] [--report] [--json] [--skip-build]

Exit code 0 only when every check passes.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from doctor import tool_paths

STANDARD_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}
# Not part of the deliverable: build output, exercise ladder, throwaway probes.
SKIP_DIRS = {".lake", ".vibecheck", "lake-packages", "Learn", "Scratch"}

# (pattern, severity, why)
CHEATS = [
    (r"\bsorry\b", "fail", "unfinished proof"),
    (r"^\s*(?:private\s+|protected\s+)?axiom\s", "fail", "assumes something without proof"),
    (r"\bnative_decide\b", "fail", "trusts the compiler instead of the kernel"),
    (r"\bimplemented_by\b", "fail", "runs different code than the code that was proved"),
    (r"debug\.skipKernelTC", "fail", "turns off the kernel check"),
    (r"@\[extern\b", "warn", "runs foreign code the proofs cannot see"),
    (r"\bunsafe\s+def\b", "warn", "unsafe code is invisible to proofs"),
    (r"\bpartial\s+def\b", "warn", "partial functions cannot be reasoned about"),
    (r"^\s*opaque\s", "warn", "opaque definitions cannot be unfolded in proofs"),
]


def strip_comments(src: str) -> str:
    """Remove Lean comments (nested block comments and line comments), keeping line numbers."""
    out, i, depth, n = [], 0, 0, len(src)
    while i < n:
        if src.startswith("/-", i):
            depth += 1
            i += 2
            continue
        if depth and src.startswith("-/", i):
            depth -= 1
            i += 2
            continue
        if depth:
            out.append("\n" if src[i] == "\n" else " ")
            i += 1
            continue
        if src.startswith("--", i):
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        if src[i] == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append(" " * (min(j + 1, n) - i))
            i = j + 1
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def find_root(start: Path) -> Path:
    for d in [start, *start.parents]:
        if (d / "lakefile.toml").exists() or (d / "lakefile.lean").exists():
            return d
    sys.exit(f"error: no lakefile.toml or lakefile.lean at or above {start}")


def find_lib(root: Path) -> str:
    toml = root / "lakefile.toml"
    if toml.exists():
        m = re.search(r'\[\[lean_lib\]\]\s*\n\s*name\s*=\s*"([^"]+)"', toml.read_text())
        if m:
            return m.group(1)
    lean = root / "lakefile.lean"
    if lean.exists():
        m = re.search(r"lean_lib\s+«?([A-Za-z0-9_.]+)»?", lean.read_text())
        if m:
            return m.group(1)
    sys.exit("error: could not find a lean_lib in the lakefile; pass --lib NAME")


def lean_sources(root: Path):
    for p in sorted(root.rglob("*.lean")):
        rel = p.relative_to(root)
        if rel.parts[0] in SKIP_DIRS or rel.name == "lakefile.lean":
            continue
        yield p


def spec_files(root: Path, lib: str):
    return [p for p in lean_sources(root)
            if p.name == "Spec.lean" or "Spec" in p.relative_to(root).parts[:-1]]


def generated_model(rel: Path) -> bool:
    """Files hax/Aeneas generate to model external Rust code."""
    return any(part in ("Assumptions", "Extraction") for part in rel.parts) or "FunsExternal" in rel.name


def read_assumptions(vdir: Path):
    """Axiom names a human accepted as trusted models, one per line, # comments allowed."""
    f = vdir / "assumptions.txt"
    if not f.exists():
        return []
    return [l.split("#", 1)[0].strip() for l in f.read_text().splitlines() if l.split("#", 1)[0].strip()]


def spec_hash(files, root: Path) -> str:
    h = hashlib.sha256()
    for p in files:
        h.update(str(p.relative_to(root)).encode())
        h.update(p.read_bytes())
    return h.hexdigest()


def main() -> int:
    tool_paths()
    ap = argparse.ArgumentParser()
    ap.add_argument("project", nargs="?", default=".")
    ap.add_argument("--lib")
    ap.add_argument("--lock", action="store_true", help="record the current Spec files as approved")
    ap.add_argument("--report", action="store_true", help="write VERIFICATION.md")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--skip-build", action="store_true")
    args = ap.parse_args()

    root = find_root(Path(args.project).expanduser().resolve())
    lib = args.lib or find_lib(root)
    vdir = root / ".vibecheck"
    vdir.mkdir(exist_ok=True)
    result = {"root": str(root), "lib": lib, "checks": {}, "specs": [], "theorems": []}
    checks = result["checks"]

    # 1. build
    if args.skip_build:
        checks["build"] = {"ok": True, "skipped": True}
    else:
        b = subprocess.run(["lake", "build"], cwd=root, capture_output=True, text=True)
        log = b.stdout + b.stderr
        sorry_lines = [l.strip() for l in log.splitlines() if "declaration uses 'sorry'" in l
                       or "declaration uses `sorry`" in l]
        errors = [l.strip() for l in log.splitlines() if re.search(r"\berror\b", l)]
        checks["build"] = {"ok": b.returncode == 0 and not sorry_lines,
                           "exit": b.returncode, "sorry_warnings": sorry_lines, "errors": errors[:20]}
        if b.returncode != 0:
            checks["build"]["tail"] = log.splitlines()[-30:]

    # 2. cheat scan
    hits = []
    for p in lean_sources(root):
        clean = strip_comments(p.read_text())
        for ln, line in enumerate(clean.splitlines(), 1):
            for pat, sev, why in CHEATS:
                if re.search(pat, line):
                    if why.startswith("assumes") and generated_model(p.relative_to(root)):
                        sev, why = "warn", ("models external code; list the axiom in .vibecheck/assumptions.txt "
                                            "once a human accepts it")
                    hits.append({"file": str(p.relative_to(root)), "line": ln, "severity": sev,
                                 "match": re.search(pat, line).group(0).strip(), "why": why})
    checks["cheats"] = {"ok": not any(h["severity"] == "fail" for h in hits), "hits": hits}

    # 3. spec lock
    specs = spec_files(root, lib)
    lock = vdir / "spec.lock"
    current = spec_hash(specs, root) if specs else None
    if args.lock and current:
        lock.write_text(json.dumps({"sha256": current,
                                    "files": [str(p.relative_to(root)) for p in specs]}, indent=2) + "\n")
    if not specs:
        checks["spec_lock"] = {"ok": False, "reason": "no Spec.lean found; properties belong in <Lib>/Spec.lean"}
    elif not lock.exists():
        checks["spec_lock"] = {"ok": True, "locked": False,
                               "note": "spec not locked yet; run with --lock once a human has reviewed it"}
    else:
        locked = json.loads(lock.read_text())["sha256"]
        checks["spec_lock"] = {"ok": locked == current, "locked": True,
                               "changed": locked != current}
        if locked != current:
            checks["spec_lock"]["reason"] = ("Spec files changed since they were locked; a human should "
                                             "review `git diff` on them, then re-run with --lock")

    # 4. property coverage and axioms (needs a successful build)
    accepted = read_assumptions(vdir)
    result["assumptions"] = accepted
    if checks["build"]["ok"] or checks["build"].get("exit") == 0 or args.skip_build:
        tmpl = Path(__file__).with_name("Audit.lean.tmpl").read_text().replace("__LIB__", lib)
        audit_file = vdir / "Audit.lean"
        audit_file.write_text(tmpl)
        a = subprocess.run(["lake", "env", "lean", str(audit_file)], cwd=root,
                           capture_output=True, text=True)
        line = next((l for l in a.stdout.splitlines() if l.startswith("VIBECHECK_AUDIT ")), None)
        if line is None:
            checks["proofs"] = {"ok": False, "error": (a.stdout + a.stderr).strip()[-2000:]}
        else:
            data = json.loads(line[len("VIBECHECK_AUDIT "):])
            allowed = STANDARD_AXIOMS | set(accepted)
            for s in data["specs"]:
                for pr in s["proofs"]:
                    pr["extra_axioms"] = [x for x in pr["axioms"] if x not in allowed]
                    pr["assumed"] = [x for x in pr["axioms"] if x in accepted]
                s["doc"] = " ".join(s["doc"].split())
                s["proved"] = any(not pr["extra_axioms"] for pr in s["proofs"])
            for t in data["theorems"]:
                t["extra_axioms"] = [x for x in t["axioms"] if x not in allowed]
            result["specs"], result["theorems"] = data["specs"], data["theorems"]
            unproved = [s["name"] for s in data["specs"] if not s["proved"]]
            tainted = [t["name"] for t in data["theorems"] if t["extra_axioms"]]
            checks["proofs"] = {"ok": bool(data["specs"]) and not unproved and not tainted,
                                "specs": len(data["specs"]), "unproved": unproved,
                                "theorems_with_extra_axioms": tainted}
            if not data["specs"]:
                checks["proofs"]["reason"] = f"no properties found in namespace {lib}.Spec"
    else:
        checks["proofs"] = {"ok": False, "reason": "skipped: build failed"}

    result["ok"] = all(c["ok"] for c in checks.values())

    if args.report:
        write_report(root, result)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print_human(result)
    return 0 if result["ok"] else 1


def mark(ok: bool) -> str:
    return "PASS" if ok else "FAIL"


def print_human(r) -> None:
    c = r["checks"]
    print(f"vibecheck audit: {r['root']}  (library {r['lib']})\n")
    b = c["build"]
    print(f"[{mark(b['ok'])}] build" + (" (skipped)" if b.get("skipped") else ""))
    for l in b.get("sorry_warnings", []):
        print(f"       {l}")
    for l in b.get("errors", [])[:10]:
        print(f"       {l}")
    ch = c["cheats"]
    print(f"[{mark(ch['ok'])}] no cheats in sources")
    for h in ch["hits"]:
        tag = "FAIL" if h["severity"] == "fail" else "warn"
        print(f"       {tag} {h['file']}:{h['line']}  {h['match']}  ({h['why']})")
    sl = c["spec_lock"]
    if sl.get("locked") is False and sl["ok"]:
        print(f"[note] spec lock: {sl['note']}")
    else:
        print(f"[{mark(sl['ok'])}] spec unchanged since lock" + (f": {sl['reason']}" if "reason" in sl else ""))
    pr = c["proofs"]
    print(f"[{mark(pr['ok'])}] every Spec property proved on standard axioms only")
    if "reason" in pr:
        print(f"       {pr['reason']}")
    if "error" in pr:
        print("       audit program failed:\n" + "\n".join("       " + l for l in pr["error"].splitlines()[-15:]))
    for s in r["specs"]:
        if s["proved"]:
            status = "proved"
        elif not s["proofs"]:
            status = "NOT PROVED: no theorem of this type yet"
        elif any("sorryAx" in p["axioms"] for p in s["proofs"]):
            status = "NOT PROVED YET: the proof still has a sorry"
        else:
            status = "PROOF USES EXTRA AXIOMS"
        print(f"\n  {s['name']}  [{status}]")
        if s["doc"]:
            print(f"    means: {s['doc']}")
        for p in s["proofs"]:
            print(f"    by {p['name']}  axioms: {', '.join(p['axioms']) or 'none'}")
            if p.get("assumed"):
                print(f"    rests on accepted assumptions: {', '.join(p['assumed'])}")
    for t in r["theorems"]:
        if t["extra_axioms"]:
            print(f"\n  theorem {t['name']} depends on: {', '.join(t['extra_axioms'])}")
    print(f"\n{'ALL CHECKS PASS' if r['ok'] else 'NOT READY'}")


def kind(doc: str):
    """Classify a property by its doc comment: 'Headline.' and 'FINDING:' prefixes are conventions."""
    d = doc.strip()
    for prefix, k in (("headline", "headline"), ("finding", "finding")):
        if d.lower().startswith(prefix):
            return k, d[len(prefix):].lstrip(" .:-")
    return "guarantee", d


def write_report(root: Path, r) -> None:
    lines = ["# Verification report", "",
             f"Generated by `vibecheck-lean/scripts/audit.py`. Overall: **{'pass' if r['ok'] else 'not ready'}**.", ""]
    groups = {"headline": [], "guarantee": [], "finding": []}
    for s in r["specs"]:
        k, meaning = kind(s["doc"])
        groups[k].append((s, meaning))
    titles = {"headline": "Headline property", "guarantee": "Guarantees",
              "finding": "Findings: proved facts about bugs in the code"}
    for k in ("headline", "guarantee", "finding"):
        if not groups[k]:
            continue
        lines += [f"## {titles[k]}", "", "| Property | Meaning | Proved by | Axioms |", "| --- | --- | --- | --- |"]
        for s, meaning in groups[k]:
            short = s["name"].split(".Spec.", 1)[-1]
            meaning = meaning or "(no doc comment)"
            if s["proofs"]:
                for p in s["proofs"]:
                    lines.append(f"| `{short}` | {meaning} | `{p['name']}` | {', '.join(p['axioms']) or 'none'} |")
            else:
                lines.append(f"| `{short}` | {meaning} | **not proved** | |")
        lines.append("")
    c = r["checks"]
    lines += ["## Checks", "",
              f"- Build: {mark(c['build']['ok'])}",
              f"- No cheat constructs (`sorry`, `axiom`, `native_decide`, ...): {mark(c['cheats']['ok'])}",
              f"- Spec unchanged since human review: {mark(c['spec_lock']['ok'])}"
              + (" (not locked)" if c["spec_lock"].get("locked") is False else ""),
              f"- Every property proved on Lean's standard axioms only: {mark(c['proofs']['ok'])}", "",
              "Lean's standard axioms are `propext`, `Classical.choice` and `Quot.sound`. "
              "\"none\" means the proof needed no axioms at all.", ""]
    if r.get("assumptions"):
        lines += ["## Trusted assumptions", "",
                  "These axioms model code outside the proof (for example Rust library functions). "
                  "A human reviewed and accepted each one; every result that uses one depends on it being accurate.", ""]
        lines += [f"- `{a}`" for a in r["assumptions"]] + [""]
    (root / "VERIFICATION.md").write_text("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())
