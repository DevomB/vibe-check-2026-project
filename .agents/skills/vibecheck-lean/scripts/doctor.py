#!/usr/bin/env python3
"""Report what a VibeCheck Lean setup has and what it is missing.

Usage: doctor.py [--json]
Read-only: installs nothing. Each missing item names the bootstrap step that fixes it.
"""
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

MAC_CODE = [
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
    str(Path.home() / "Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"),
]


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return (r.stdout + r.stderr).strip() if r.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def first_line(s):
    return s.splitlines()[0] if s else None


def find_code():
    for name in ("code", "cursor", "codium"):
        p = shutil.which(name)
        if p:
            return p
    for p in MAC_CODE:
        if Path(p).exists():
            return p
    return None


def tool_paths():
    """Find user-local installs without requiring a new login shell."""
    dirs = [Path.home() / p for p in (".elan/bin", ".local/bin", ".cargo/bin")]
    os.environ["PATH"] = os.pathsep.join([str(p) for p in dirs if p.is_dir()] +
                                           [os.environ.get("PATH", "")])


def inspect(mode="editor", rung="learn", rust=False, node=False):
    tool_paths()
    system = platform.system()
    checks = []

    def add(key, ok, detail, fix=None, needed_for="core"):
        checks.append({"key": key, "ok": ok, "detail": detail, "fix": fix, "needed_for": needed_for})

    if system == "Windows":
        add("os", False, "native Windows", "Install WSL2 (`wsl --install`), then run everything inside Ubuntu")
    else:
        add("os", True, f"{system} {platform.machine()}")

    for binary in ("elan", "lean", "lake"):
        executable = shutil.which(binary)
        elan = shutil.which("elan")
        # Running an elan proxy can download a missing toolchain. Resolve the
        # installed binary first so this diagnostic remains read-only.
        if executable and elan and binary != "elan" and os.path.samefile(executable, elan):
            executable = run([elan, "which", binary])
        version = first_line(run([executable, "--version"])) if executable else None
        add(binary, bool(version), version or "missing or not working", "bootstrap.sh elan")

    code = find_code()
    add("editor", bool(code), code or "no VS Code, Cursor or VSCodium CLI found", "bootstrap.sh vscode",
        needed_for="editor")
    if code and mode == "editor":
        exts = run([code, "--list-extensions"]) or ""
        has = "leanprover.lean4" in exts.lower()
        add("lean4-extension", has, "installed" if has else "missing", "bootstrap.sh vscode", needed_for="editor")
    else:
        add("lean4-extension", False, "not checked in chat mode" if mode == "chat" else "needs an editor first",
            "bootstrap.sh vscode", needed_for="editor")

    add("git", bool(shutil.which("git")), "present" if shutil.which("git") else "missing",
        "bootstrap.sh prereqs")
    for binary in ("curl", "tar", "make", "cc"):
        works = bool(shutil.which(binary))
        if binary == "cc" and system == "Darwin":
            works = works and run(["xcode-select", "-p"]) is not None
        add(binary, works, "present" if works else "missing", "bootstrap.sh prereqs")
    add("uvx", bool(shutil.which("uvx")), "present" if shutil.which("uvx") else "missing",
        "bootstrap.sh uv", needed_for="agent (lean-lsp-mcp)")
    add("claude", bool(shutil.which("claude")), "present" if shutil.which("claude") else "missing",
        "https://docs.claude.com/en/docs/claude-code", needed_for="agent")
    add("python3", sys.version_info >= (3, 10), first_line(run(["python3", "--version"])) or "missing",
        "bootstrap.sh prereqs", needed_for="audit, differential tests")

    cargo = shutil.which("cargo")
    add("cargo", bool(cargo), first_line(run(["cargo", "--version"])) if cargo else "missing",
        "bootstrap.sh rust", needed_for="Track B: Rust")
    hax = shutil.which("cargo-hax")
    add("cargo-hax", bool(hax), (run(["cargo", "hax", "--version"]) or "").replace("\n", " ") if hax else "missing",
        "bootstrap.sh hax", needed_for="Track B: Rust")
    add("node", bool(shutil.which("node")), "present" if shutil.which("node") else "missing",
        "bootstrap.sh node", needed_for="Track B: TypeScript/JavaScript differential tests")

    required = {"os", "elan", "lean", "lake", "git", "curl", "tar", "make", "cc", "python3"}
    if mode == "editor":
        required.update(("editor", "lean4-extension"))
    if rung in ("build-app", "spec-existing"):
        required.add("uvx")
    if rust:
        required.update(("cargo", "cargo-hax"))
    if node:
        required.add("node")
    for check in checks:
        check["required"] = check["key"] in required
    core_ok = all(c["ok"] for c in checks if c["required"])
    return {"core_ready": core_ok, "mode": mode, "rung": rung, "editor_cli": code, "checks": checks}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--mode", choices=("chat", "editor"), default="editor")
    ap.add_argument("--rung", choices=("learn", "refresh", "build-app", "spec-existing"), default="learn")
    ap.add_argument("--rust", action="store_true", help="require the Rust extraction route")
    ap.add_argument("--node", action="store_true", help="require JavaScript differential tests")
    args = ap.parse_args()
    out = inspect(args.mode, args.rung, args.rust, args.node)
    if args.json:
        print(json.dumps(out, indent=2))
        return
    print("vibecheck doctor\n")
    for c in out["checks"]:
        mark = "ok  " if c["ok"] else "MISS"
        scope = "  [required]" if c["required"] else f"  [optional: {c['needed_for']}]"
        print(f"  {mark} {c['key']:<16} {c['detail']}{scope}")
        if not c["ok"] and c["fix"]:
            print(f"       fix: {c['fix']}")
    print("\ncore setup ready" if out["core_ready"] else "\ncore setup incomplete")


if __name__ == "__main__":
    main()
