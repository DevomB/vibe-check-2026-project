#!/usr/bin/env python3
"""Scaffold a VibeCheck Lean project: Impl / Spec / Proofs split, agent rules,
lean-lsp MCP config, VS Code recommendation, and a warm build.

Usage: new_project.py NAME [--dir PARENT] [--starter undo|gcounter|rle] [--no-build] [--no-git]

--starter replaces the template's ledger example with a ready-made app whose spec is
written and whose proofs are `sorry`: the team's job is to prove them. A starter's
reference solution stays in the skill (assets/starters/NAME/solution/), not the project.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from doctor import tool_paths

SKILL = Path(__file__).resolve().parent.parent
TEMPLATE = SKILL / "assets" / "template"
STARTERS = SKILL / "assets" / "starters"


def lib_name(pkg: str) -> str:
    parts = [p for p in re.split(r"[^A-Za-z0-9]+", pkg) if p]
    name = "".join(p[:1].upper() + p[1:] for p in parts)
    if not name or name[0].isdigit():
        name = "Vibe" + name
    return name


def toolchain() -> str:
    try:
        out = subprocess.run(["lean", "--version"], capture_output=True, text=True, check=True).stdout
        m = re.search(r"version (\d+\.\d+\.\d+(?:-rc\d+)?)", out)
        if m:
            return f"leanprover/lean4:v{m.group(1)}"
    except (OSError, subprocess.CalledProcessError):
        pass
    return "leanprover/lean4:stable"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def main() -> int:
    tool_paths()
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--dir", default=".")
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--no-git", action="store_true")
    ap.add_argument("--starter", choices=sorted(p.name for p in STARTERS.iterdir() if p.is_dir())
                    if STARTERS.exists() else [])
    args = ap.parse_args()

    pkg = re.sub(r"[^a-z0-9_-]+", "-", args.name.lower()).strip("-") or "vibe"
    lib = lib_name(pkg)
    root = Path(args.dir).expanduser().resolve() / pkg
    if root.exists() and any(root.iterdir()):
        print(f"error: {root} already exists and is not empty", file=sys.stderr)
        return 1

    layers = [TEMPLATE] + ([STARTERS / args.starter] if args.starter else [])
    for layer in layers:
        for src in layer.rglob("*"):
            rel_src = src.relative_to(layer)
            if src.is_dir() or rel_src.parts[0] == "solution":
                continue
            rel = Path(str(rel_src).replace("__LIB__", lib))
            write(root / rel, src.read_text().replace("__LIB__", lib).replace("__PKG__", pkg))

    write(root / "lean-toolchain", toolchain() + "\n")
    write(root / "lakefile.toml", f'''name = "{pkg}"
version = "0.1.0"
defaultTargets = ["{pkg}"]

[[lean_lib]]
name = "{lib}"

[[lean_exe]]
name = "{pkg}"
root = "Main"
''')
    write(root / ".gitignore", "/.lake\n/.vibecheck/Audit.lean\n/.vibecheck/chat/\n"
          "/.vibecheck/start.html\n/.vibecheck/lessons/\n/.vibecheck/progress.json\n__pycache__/\n*.pyc\n.env\n.env.*\n*.pem\n*.key\n")
    # Ship portable audit tools with the project, rather than exposing the
    # skill installation path or requiring judges to install the same skill.
    for filename in ("audit.py", "doctor.py", "Audit.lean.tmpl"):
        write(root / ".vibecheck" / "tools" / filename, (SKILL / "scripts" / filename).read_text())
    # Codex and other agents read AGENTS.md; Claude Code reads CLAUDE.md. Same rules for both.
    write(root / "AGENTS.md", (root / "CLAUDE.md").read_text())
    write(root / ".mcp.json", json.dumps(
        {"mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"]}}}, indent=2) + "\n")
    write(root / ".vscode" / "extensions.json", json.dumps(
        {"recommendations": ["leanprover.lean4"]}, indent=2) + "\n")
    write(root / ".vibecheck" / "progress.json", json.dumps(
        {"project": pkg, "lib": lib, "starter": args.starter, "track": None, "level": 0,
         "completed": [], "notes": []}, indent=2) + "\n")

    if not args.no_git and shutil.which("git"):
        subprocess.run(["git", "init", "-q"], cwd=root)
    if not args.no_build:
        print("building (first build fetches the toolchain if needed)...", flush=True)
        r = subprocess.run(["lake", "build"], cwd=root)
        if r.returncode != 0:
            print("error: lake build failed; see output above", file=sys.stderr)
            return r.returncode
    print(json.dumps({"root": str(root), "package": pkg, "lib": lib, "starter": args.starter,
                      "files": {"impl": f"{lib}/Impl.lean", "spec": f"{lib}/Spec.lean",
                                "proofs": f"{lib}/Proofs.lean", "main": "Main.lean"}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
