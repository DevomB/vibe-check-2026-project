#!/usr/bin/env bash
# Install the event preview for Codex, OpenCode and Claude Code.
set -euo pipefail

install_home="$HOME"
repository="https://github.com/modiqo/vibecheck-lean.git"
release_ref="v0.2.1-event-preview"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --home|--repo|--ref)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      case "$1" in
        --home) install_home="$2" ;;
        --repo) repository="$2" ;;
        --ref) release_ref="$2" ;;
      esac
      shift 2
      ;;
    -h|--help)
      echo "Usage: install.sh [--home DIR] [--repo URL] [--ref TAG]"
      echo "Installs into .agents/skills and links .claude/skills under DIR (default: your home)."
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "Install git, then rerun this installer." >&2; exit 1; }
target="$install_home/.agents/skills/vibecheck-lean"
claude_link="$install_home/.claude/skills/vibecheck-lean"

# Check both destinations before changing either. Existing installations belong
# to the user; never overwrite them or pull over their local changes.
if [ -e "$target" ] || [ -L "$target" ]; then
  [ -f "$target/SKILL.md" ] && [ -f "$target/scripts/chat.py" ] || {
    echo "An unrelated or incomplete installation exists at $target; left unchanged." >&2
    exit 1
  }
fi
if [ -e "$claude_link" ] || [ -L "$claude_link" ]; then
  [ "$claude_link" -ef "$target" ] || {
    echo "A different Claude Code installation exists at $claude_link; left unchanged." >&2
    exit 1
  }
fi

if [ ! -e "$target" ]; then
  mkdir -p "$install_home/.agents/skills"
  temporary="$(mktemp -d "$install_home/.agents/skills/.vibecheck-install.XXXXXX")"
  trap 'if [ -n "${temporary:-}" ] && [ -d "$temporary" ]; then rm -rf -- "$temporary"; fi' EXIT
  git clone --depth 1 --branch "$release_ref" -- "$repository" "$temporary/skill"
  [ -f "$temporary/skill/SKILL.md" ] && [ -f "$temporary/skill/scripts/chat.py" ] || {
    echo "The selected source does not contain the complete skill." >&2
    exit 1
  }
  mv "$temporary/skill" "$target"
  echo "Installed $release_ref at $target"
else
  echo "Existing installation kept at $target"
fi

if [ ! -e "$claude_link" ] && [ ! -L "$claude_link" ]; then
  mkdir -p "$install_home/.claude/skills"
  ln -s ../../.agents/skills/vibecheck-lean "$claude_link"
fi
echo "Ready for Codex, OpenCode and Claude Code. Start a new agent session and ask to learn Lean."
echo "Lean setup runs through the skill after you approve its dependency plan."
