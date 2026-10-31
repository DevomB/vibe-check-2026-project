#!/usr/bin/env bash
# Install the pieces of a VibeCheck Lean setup, one step at a time.
#
# Usage: bootstrap.sh STEP [ARGS]
#   prereqs         install curl, git, tar, C build tools and Python where supported
#   elan            install elan + the stable Lean toolchain
#   vscode          install VS Code (macOS + Homebrew only) and the Lean 4 extension
#   uv              install uv, which runs the lean-lsp MCP server
#   rust            install Rust for the extraction route
#   node            install Node.js for JavaScript differential tests
#   mcp [DIR]       register lean-lsp-mcp for the Lean project in DIR (default: .)
#   hax             install cargo-hax (Rust -> Lean via Charon + Aeneas)
#   open DIR [FILE] open a project in the editor
#
# Every step is idempotent and prints each command before running it. Steps never
# call sudo: when a system package needs administrator rights, the step prints the
# command for the user to run and exits with status 3.
set -euo pipefail
export PATH="$HOME/.elan/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

say() { printf '\n==> %s\n' "$*"; }
run() { printf '    $ %s\n' "$*"; "$@"; }

# Run system package commands as root, or hand them to the user.
as_root() {
  if [ "$(id -u)" = 0 ]; then
    for command in "$@"; do run sh -c "$command"; done
    return
  fi
  joined=""
  for command in "$@"; do joined="${joined:+$joined && }sudo $command"; done
  echo "This step needs administrator rights. Run this yourself, then rerun setup:" >&2
  echo "    $joined" >&2
  exit 3
}

# Download an official installer to a file over HTTPS, then run it from there.
fetch_and_run() {
  url="$1"; shift
  script="$(mktemp)"
  status=0
  run curl --proto '=https' --tlsv1.2 -sSfL "$url" -o "$script" || status=$?
  [ "$status" = 0 ] && { run sh "$script" "$@" || status=$?; }
  rm -f "$script"
  return "$status"
}

packages() {
  if command -v brew >/dev/null 2>&1; then
    run brew install "$@"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root "apt-get update" "apt-get install -y $*"
  elif command -v dnf >/dev/null 2>&1; then
    as_root "dnf install -y $*"
  else
    echo "No supported package manager found. Install these packages, then rerun setup: $*" >&2
    return 1
  fi
}

code_cli() {
  for c in code cursor codium; do command -v "$c" >/dev/null 2>&1 && { echo "$c"; return; }; done
  for p in "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
           "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  return 1
}

step="${1:-}"; shift || true
case "$step" in
  prereqs)
    if [ "$(uname)" = "Darwin" ]; then
      if ! xcode-select -p >/dev/null 2>&1; then
        run xcode-select --install
        echo "Finish the Command Line Tools installer, then rerun setup." >&2
        exit 1
      fi
      for binary in curl git tar make cc; do
        command -v "$binary" >/dev/null 2>&1 || { echo "Missing $binary after Command Line Tools installation" >&2; exit 1; }
      done
      command -v python3 >/dev/null 2>&1 || packages python
    elif command -v apt-get >/dev/null 2>&1; then
      packages curl ca-certificates git tar build-essential python3
    elif command -v dnf >/dev/null 2>&1; then
      packages curl ca-certificates git tar gcc make python3
    else
      echo "Install curl, CA certificates, git, tar, a C compiler, make and Python 3.10+, then rerun setup." >&2
      exit 1
    fi
    ;;
  elan)
    requested_toolchain="stable"
    if [ -f lean-toolchain ]; then requested_toolchain="$(cat lean-toolchain)"; fi
    if command -v elan >/dev/null 2>&1; then
      say "elan already installed; making sure $requested_toolchain is present"
      run elan toolchain install "$requested_toolchain"
      if ! lean --version >/dev/null 2>&1; then run elan default "$requested_toolchain"; fi
    else
      say "installing elan (the Lean version manager) and stable Lean"
      fetch_and_run https://elan.lean-lang.org/elan-init.sh -y --default-toolchain "$requested_toolchain"
      echo "    open a new terminal, or run: source \"\$HOME/.elan/env\""
    fi
    ;;
  vscode)
    if ! cli="$(code_cli)"; then
      if [ "$(uname)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        say "installing VS Code with Homebrew"
        run brew install --cask visual-studio-code
        cli="$(code_cli)"
      else
        echo "VS Code not found. Install it from https://code.visualstudio.com, then rerun this step." >&2
        exit 1
      fi
    fi
    say "installing the Lean 4 extension"
    run "$cli" --install-extension leanprover.lean4 --force
    ;;
  uv)
    if command -v uvx >/dev/null 2>&1; then say "uv already installed"; exit 0; fi
    say "installing uv"
    if command -v brew >/dev/null 2>&1; then run brew install uv; else fetch_and_run https://astral.sh/uv/install.sh; fi
    ;;
  rust)
    if command -v cargo >/dev/null 2>&1; then say "Rust already installed"; exit 0; fi
    say "installing Rust for the extraction route"
    fetch_and_run https://sh.rustup.rs -y --profile minimal
    ;;
  node)
    if command -v node >/dev/null 2>&1; then say "Node.js already installed"; exit 0; fi
    say "installing Node.js for differential tests"
    if command -v brew >/dev/null 2>&1; then packages node; else packages nodejs npm; fi
    ;;
  mcp)
    dir="${1:-.}"
    cd "$dir"
    if [ -f .mcp.json ] && grep -q lean-lsp .mcp.json; then
      say "lean-lsp already registered in $(pwd)/.mcp.json"
    else
      say "registering lean-lsp-mcp for $(pwd)"
      run command claude mcp add -s project lean-lsp -- uvx lean-lsp-mcp
    fi
    say "warming the build so the MCP server does not time out on first start"
    run lake build
    echo "    restart Claude Code in this folder and approve the lean-lsp server when asked"
    ;;
  hax)
    if command -v cargo-hax >/dev/null 2>&1; then say "cargo-hax already installed"; cargo hax --version; exit 0; fi
    command -v cargo >/dev/null 2>&1 || { echo "cargo not found; install Rust from https://rustup.rs" >&2; exit 1; }
    say "installing cargo-hax (about a minute; it fetches Charon and Aeneas on first use)"
    run cargo install --locked cargo-hax
    ;;
  open)
    dir="${1:?usage: bootstrap.sh open DIR [FILE]}"; file="${2:-}"
    cli="$(code_cli)" || { echo "no editor CLI found; run: bootstrap.sh vscode" >&2; exit 1; }
    if [ -n "$file" ]; then run "$cli" "$dir" "$dir/$file"; else run "$cli" "$dir"; fi
    ;;
  *)
    sed -n '2,13p' "$0"; exit 1 ;;
esac
