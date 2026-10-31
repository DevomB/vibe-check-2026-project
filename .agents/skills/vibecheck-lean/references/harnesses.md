# Run the same lessons across harnesses

The skill uses standard `SKILL.md` instructions and Python, Bash, Lean and Lake commands.
The host supplies file editing, command execution and conversation. No harness SDK or model API key is required.
Chat execution works without MCP. Use a connected Lean language server when available, with the CLI as the fallback.

## Install in a location the host discovers

Place the entire skill folder at a supported path, including scripts, references and assets:

| Harness | User-level skill directory | Project-level alternative |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/vibecheck-lean/` | `.claude/skills/vibecheck-lean/` |
| Codex | `~/.agents/skills/vibecheck-lean/` | `.agents/skills/vibecheck-lean/` |
| OpenCode | `~/.config/opencode/skills/vibecheck-lean/` | `.opencode/skills/vibecheck-lean/` |

See the official [Claude Code](https://code.claude.com/docs/en/skills),
[Codex](https://developers.openai.com/codex/skills/), and [OpenCode](https://opencode.ai/docs/skills/) discovery documentation.
OpenCode also discovers the Claude-compatible and agent-compatible locations listed in its documentation.
Keep one source folder and use supported links or copies; avoid loading conflicting copies of the same skill.
Resolve `<skill>` from the loaded `SKILL.md` location, never from a hard-coded home directory.

For a shared user installation, prefer `~/.agents/skills/vibecheck-lean/` as the canonical folder.
Codex and OpenCode discover it. Claude Code can use a relative link from `~/.claude/skills/vibecheck-lean/` to that folder.
For a shared repository installation, use `.agents/skills/vibecheck-lean/` and a relative Claude link under `.claude/skills/`.
The relative target from either Claude skills directory is `../../.agents/skills/vibecheck-lean`.
Do not overwrite an existing installation or use the singular `.agent` as a supposed universal convention.

## Adapt capabilities without changing the lesson

- Use the host's question tool if it fits; otherwise use the numbered-text placement flow.

- Use the host's command tool to run the scripts, preserving cwd, arguments, exit code and output.

- Use `chat.py --code` for a short snippet, shell-quoting it as data, or a UTF-8 file for multiline source.

- Prefer compact `chat.py` output. Use `--format json` only to investigate a failure or consume metadata programmatically.

- Read generated `AGENTS.md` in Codex or OpenCode, and `CLAUDE.md` in Claude Code. Both contain matching rules.

- Honor the host's permissions. An installation authorization does not disable its security controls.

Profiles live in `~/.vibecheck/profile.json`, independent of the host.
The project files and `.vibecheck/chat/` history also carry between hosts on the same machine.
For another machine, transfer the project and profile explicitly; the skill does not synchronize them over a service.

## Keep the learner's display compact

Prefer the real result or error, a small syntax tree, and a short explanation.
Keep commands, source snapshots, exit codes and full diagnostics in the spool files.
Do not print the runner's JSON metadata into routine lesson output.
Prefer a direct script call with a file or quoted `--code` over a Python heredoc.

The host controls tool activity rows, timing badges and transcript expansion.
A skill cannot portably suppress or replace those elements. Do not promise to hide them or invent a shared setting.
If the learner requests display changes, consult that host's documented controls before suggesting a setting.
Keep approvals and meaningful errors visible.

For light status messages, read the humor guidance in `chat-workspace.md`.
Use the same teaching tone across hosts; do not make jokes depend on UI hooks.

## Optional language-server registration

Register MCP only when requested or authorized. Configuration formats belong to the host:

- Claude Code can use the generated `.mcp.json` or `bootstrap.sh mcp DIR`.

- Codex can register `lean-lsp` with `codex mcp add lean-lsp -- uvx lean-lsp-mcp`; this changes global Codex configuration.

- For OpenCode, follow its [MCP configuration documentation](https://opencode.ai/docs/mcp-servers/); do not write Claude's format to `opencode.json`.

Build the project before starting the server. If the server is unavailable, continue using CLI checks in the same chat.
