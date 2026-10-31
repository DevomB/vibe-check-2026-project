#!/usr/bin/env python3
"""Look at an existing repository and recommend a Track B verification route.

Usage: detect_repo.py REPO_DIR [--json] [--top N]

Reports the language mix, Rust features that block extraction, signs that the
code is a distributed protocol, and a ranked list of small, pure-looking
functions that make good first verification targets. Read-only.
"""
import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", "target", ".venv", "venv", "env", "dist", "build", "out",
             ".lake", "lake-packages", "vendor", "third_party", "__pycache__", ".next", ".tox",
             ".mypy_cache", "coverage", ".idea", ".vscode", "site-packages", "Pods"}

LANGS = {
    ".py": "Python", ".rs": "Rust", ".ts": "TypeScript", ".tsx": "TypeScript", ".js": "JavaScript",
    ".jsx": "JavaScript", ".mjs": "JavaScript", ".go": "Go", ".c": "C", ".h": "C", ".cc": "C++",
    ".cpp": "C++", ".hpp": "C++", ".java": "Java", ".kt": "Kotlin", ".swift": "Swift", ".rb": "Ruby",
    ".cs": "C#", ".hs": "Haskell", ".ml": "OCaml", ".scala": "Scala", ".sol": "Solidity",
    ".lean": "Lean", ".dfy": "Dafny", ".tla": "TLA+", ".zig": "Zig", ".ex": "Elixir", ".php": "PHP",
}

MANIFESTS = {"Cargo.toml": "Rust", "package.json": "JavaScript/TypeScript", "pyproject.toml": "Python",
             "setup.py": "Python", "requirements.txt": "Python", "go.mod": "Go", "CMakeLists.txt": "C/C++",
             "Makefile": "make", "pom.xml": "Java", "build.gradle": "Java/Kotlin", "lakefile.toml": "Lean",
             "lakefile.lean": "Lean", "foundry.toml": "Solidity", "Package.swift": "Swift"}

PROTOCOL_WORDS = re.compile(
    r"\b(raft|paxos|consensus|quorum|leader[_ ]?election|two[_ -]?phase[_ -]?commit|2pc|gossip|"
    r"vector[_ ]?clock|lamport|crdt|byzantine|bft|append[_ ]?entries|request[_ ]?vote)\b",
    re.I)

IO_WORDS = re.compile(
    r"\b(open|fetch|requests\.|http|socket|fs\.|os\.|sys\.|subprocess|"
    r"File::|std::fs|std::net|tokio|async|await|reqwest|ioutil|net/http|"
    r"Date\.now|time\.|random|Math\.random|process\.|db\.|query\(|cursor|sql|stdin|stdout|scanf|printf|malloc|"
    r"io::|Writer|Reader|BufRead|write!|writeln!|flush)\b|\.(?:read|write|flush)\w*\(")

# Logging and printing are easy to strip from a port, so they cost less than real I/O.
LIGHT_IO_WORDS = re.compile(r"\b(print|println|console\.\w+|logger|logging|log\.\w+|fmt\.Print\w*|eprintln!|println!|tracing::)")

BRANCH_WORDS = re.compile(r"\b(if|match|switch|case|while|for|elif|else)\b")

# start-of-function patterns per language; group 1 is the name
FUNC_PATTERNS = {
    "Python": re.compile(r"^(\s*)def\s+([A-Za-z_]\w*)\s*\("),
    "Rust": re.compile(r"^(\s*)(?:pub(?:\([^)]*\))?\s+)?(?:const\s+)?(?:unsafe\s+)?(?:async\s+)?fn\s+([A-Za-z_]\w*)"),
    "Go": re.compile(r"^()func\s+(?:\([^)]*\)\s*)?([A-Za-z_]\w*)\s*\("),
    "TypeScript": re.compile(r"^(\s*)(?:export\s+)?(?:default\s+)?(?:async\s+)?(?:function\s+([A-Za-z_$][\w$]*)|"
                             r"(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?\([^)]*\)\s*(?::[^=]+)?=>)"),
    "C": re.compile(r"^()(?:static\s+)?(?:inline\s+)?[A-Za-z_][\w\s\*]*?\b([A-Za-z_]\w*)\s*\([^;]*\)\s*\{?\s*$"),
}
FUNC_PATTERNS["JavaScript"] = FUNC_PATTERNS["TypeScript"]
FUNC_PATTERNS["C++"] = FUNC_PATTERNS["C"]


def is_test_path(rel: Path) -> bool:
    s = str(rel).lower()
    return any(t in s for t in ("test", "spec.", "__tests__", "fixtures", "mock", "bench", "example"))


def walk(root: Path):
    stack = [root]
    while stack:
        d = stack.pop()
        try:
            entries = list(d.iterdir())
        except OSError:
            continue
        for p in entries:
            if p.is_dir():
                if p.name not in SKIP_DIRS and not p.name.startswith("."):
                    stack.append(p)
            elif p.is_file():
                yield p


def function_spans(lines, lang):
    """Yield (name, start_idx, end_idx) using indentation (Python) or brace counting."""
    pat = FUNC_PATTERNS.get(lang)
    if not pat:
        return
    i, n = 0, len(lines)
    while i < n:
        m = pat.match(lines[i])
        if not m:
            i += 1
            continue
        name = next((g for g in m.groups()[1:] if g), None)
        if not name or name in ("if", "for", "while", "switch", "return", "main"):
            i += 1
            continue
        if lang == "Python":
            indent = len(m.group(1))
            j = i + 1
            while j < n and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > indent):
                j += 1
            yield name, i, j
            i = j
            continue
        depth, seen, j = 0, False, i
        while j < n and j < i + 400:
            depth += lines[j].count("{") - lines[j].count("}")
            seen = seen or "{" in lines[j]
            if seen and depth <= 0:
                break
            if not seen and lines[j].rstrip().endswith(";"):
                break
            j += 1
        if seen:
            yield name, i, j + 1
        i = j + 1 if seen else i + 1


def score(body: str, nlines: int) -> float:
    if nlines < 4 or nlines > 120:
        return 0.0
    io_hits = len(IO_WORDS.findall(body)) + 0.25 * len(LIGHT_IO_WORDS.findall(body))
    branches = len(BRANCH_WORDS.findall(body))
    size = 1.0 - abs(nlines - 25) / 60
    return max(0.0, size) + min(branches, 8) * 0.25 - io_hits * 1.5


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--top", type=int, default=10)
    args = ap.parse_args()
    root = Path(args.repo).expanduser().resolve()
    if not root.is_dir():
        sys.exit(f"error: {root} is not a directory")

    loc = Counter()
    manifests = []
    rust = Counter()
    protocol_hits = Counter()
    protocol_files = defaultdict(int)
    candidates = []

    for p in walk(root):
        rel = p.relative_to(root)
        if p.name in MANIFESTS:
            manifests.append({"file": str(rel), "ecosystem": MANIFESTS[p.name]})
        lang = LANGS.get(p.suffix.lower())
        if not lang:
            continue
        try:
            text = p.read_text(errors="ignore")
        except OSError:
            continue
        if len(text) > 2_000_000:
            continue
        lines = text.splitlines()
        code_lines = sum(1 for l in lines if l.strip())
        loc[lang] += code_lines
        for m in PROTOCOL_WORDS.findall(text):
            protocol_hits[m.lower()] += 1
            protocol_files[str(rel)] += 1
        if lang == "Rust":
            rust["unsafe"] += len(re.findall(r"\bunsafe\b", text))
            rust["async"] += len(re.findall(r"\basync\b", text))
            rust["dyn"] += len(re.findall(r"\bdyn\b", text))
            rust["refcell_or_cell"] += len(re.findall(r"\b(?:RefCell|Cell|Mutex|RwLock|Rc|Arc)\s*<", text))
            rust["macro_rules"] += len(re.findall(r"\bmacro_rules!", text))
            rust["fns"] += len(re.findall(r"\bfn\s+\w", text))
        if is_test_path(rel):
            continue
        for name, a, b in function_spans(lines, lang):
            body = "\n".join(lines[a:b])
            s = score(body, b - a)
            if s > 0.6:
                candidates.append({"file": str(rel), "line": a + 1, "name": name, "language": lang,
                                   "lines": b - a, "score": round(s, 2),
                                   "io_hits": len(IO_WORDS.findall(body)),
                                   "light_io": bool(LIGHT_IO_WORDS.search(body))})

    total = sum(loc.values()) or 1
    mix = [{"language": l, "lines": n, "share": round(n / total, 3)} for l, n in loc.most_common()]
    primary = mix[0]["language"] if mix else None
    protocol_score = sum(protocol_hits.values())
    is_protocol = protocol_score >= 15 and len(protocol_files) >= 2

    routes = []
    reasons = []
    if primary == "Lean":
        routes.append("lean-native")
        reasons.append("The repo is already Lean: add a Spec.lean and prove properties of the existing definitions.")
    elif primary == "Rust":
        heavy = rust["unsafe"] + rust["async"] + rust["refcell_or_cell"]
        if heavy <= max(3, rust["fns"] // 20):
            routes.append("rust-extract")
            reasons.append(f"Rust with little unsafe/async/interior mutability "
                           f"(unsafe={rust['unsafe']}, async={rust['async']}, cells/locks={rust['refcell_or_cell']}): "
                           "extract a pure module with `cargo hax into lean` (Charon + Aeneas) and prove facts about the real code.")
        else:
            reasons.append(f"Rust that leans on unsafe/async/interior mutability (unsafe={rust['unsafe']}, "
                           f"async={rust['async']}, cells/locks={rust['refcell_or_cell']}): whole-crate extraction "
                           "will fail. Extract one pure function with --start-from, or port it.")
            routes.append("rust-extract-one-function")
        routes.append("port-prove-difftest")
    elif primary in ("Dafny", "TLA+"):
        routes.append("existing-spec")
        reasons.append(f"The repo is {primary}: it already carries a spec. Port the spec to Lean only if the event requires Lean.")
    elif primary:
        routes.append("port-prove-difftest")
        reasons.append(f"{primary} has no Lean extraction pipeline: port the pure core to Lean, prove it, "
                       "then differential-test the original against the compiled Lean port.")
        if primary in ("C", "C++", "Rust", "Go", "Zig", "Swift"):
            routes.append("port-prove-replace")
            reasons.append("The language can call a C ABI, so the verified Lean port can replace the original core.")
    if is_protocol:
        routes.insert(0 if primary not in ("Rust", "Lean") else 1, "veil-protocol")
        reasons.append(f"Protocol vocabulary appears {protocol_score} times across {len(protocol_files)} files "
                       f"({', '.join(k for k, _ in protocol_hits.most_common(4))}): model the protocol design in Veil "
                       "and prove its safety invariant; this checks the design, not the code.")

    candidates.sort(key=lambda c: (-c["score"], c["lines"]))
    out = {
        "repo": str(root),
        "primary_language": primary,
        "language_mix": mix[:8],
        "manifests": manifests[:20],
        "rust_features": dict(rust) if rust else None,
        "protocol_signals": {"score": protocol_score, "files": len(protocol_files),
                             "words": dict(protocol_hits.most_common(8))} if protocol_score else None,
        "recommended_routes": routes,
        "reasons": reasons,
        "candidates": candidates[:args.top],
    }
    if args.json:
        print(json.dumps(out, indent=2))
        return 0

    print(f"repo: {root}")
    print("languages: " + ", ".join(f"{m['language']} {m['share']:.0%}" for m in mix[:6]) if mix else "languages: none found")
    if manifests:
        print("manifests: " + ", ".join(m["file"] for m in manifests[:8]))
    if rust:
        print("rust features: " + ", ".join(f"{k}={v}" for k, v in rust.items()))
    print("\nrecommended routes (best first): " + " -> ".join(routes or ["none"]))
    for r in reasons:
        print(f"  - {r}")
    if candidates:
        print("\nfirst targets (small, branchy, no I/O):")
        for c in candidates[:args.top]:
            note = ", has logging/printing to strip when porting" if c["light_io"] else ""
            print(f"  {c['file']}:{c['line']}  {c['name']}  ({c['lines']} lines, score {c['score']}{note})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
