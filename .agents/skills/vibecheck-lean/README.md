# vibecheck-lean

Learn Lean in chat by building useful programs and proving properties about them.

[Find it on skills.sh](https://skills.sh/modiqo/vibecheck-lean/vibecheck-lean).

## Install

Requires Node.js 22.20+, git and Python 3.10+. Runs on macOS, Linux or Windows through WSL2.

Install through the [Skills CLI](https://skills.sh/docs/cli) and choose Claude Code, Codex or OpenCode:

```bash
npx skills add modiqo/vibecheck-lean -g
```

Start a new agent chat and say:

> Teach me Lean. I know Rust and have 15 minutes.

## Build something, then prove it

- **Learn:** grow an API checker from your first function through retries, invariants and proofs.
- **Build:** create an app with properties you can check.
- **Verify:** bring existing code and state what must always hold.
- **Refresh:** revisit what you learned with short, spaced drills.

Every level opens with an illustrated lesson: each piece of new syntax labelled in an annotated tree,
what Lean accepts and rejects (with the errors it really prints), and one exercise to try right away.
Type Lean directly in chat. Get the actual result, a small syntax tree and an explanation of each step.
The agent helps install missing Lean tools and keeps your progress between lessons.

Proofs cover the program logic you specify. Network I/O and external services remain outside those proofs.

[Event preview details](references/event-preview.md) · [How the project grows](references/project-ladder.md) · [Harness setup](references/harnesses.md)
