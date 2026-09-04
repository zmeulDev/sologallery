# CLAUDE.md

**All project rules live in [AGENTS.md](AGENTS.md) — read it first.** It is the
canonical instruction file: absolute rules, stack, conventions, workflow, test
strategy, verification commands, Definition of Done, gotchas and environment.

Supporting docs: [PRD.md](PRD.md) (what the product is) ·
[ARCHITECTURE.md](ARCHITECTURE.md) (how it is built) ·
[docs/design-system.md](docs/design-system.md) (visual language) ·
[docs/gotchas.md](docs/gotchas.md) (traps) · [docs/plans/](docs/plans/)
(in-flight task state).

This file adds only what is specific to Claude Code.

---

## Plan first, then wait

1. Ask clarifying questions until the task is genuinely understood.
2. Present the plan and **save it to `docs/plans/<task>.md`**.
3. **Stop.** Wait for an explicit go-ahead before writing any code.

The plan doc is a living handoff log — check off steps as you go, record
decisions and why, and keep a "Next step" line current, so a fresh session can
read AGENTS.md plus the plan and resume immediately.

---

## Delegate to sub-agents

Keep the main session small and token-cheap. Sub-agents return summaries, not raw
output. Prefer several **parallel** agents for independent chunks over one serial
sweep.

**Delegate:**
- codebase exploration before planning (Explore agent)
- digesting `adb logcat` / `dumpsys dropbox`
- running `tool/check.sh` and reporting failures
- reviewing a diff against AGENTS.md
- well-defined, self-contained edits

**Keep in the main session:**
- architecture and schema decisions
- anything whose intermediate reasoning must stay visible in the plan

**Every invocation:** a self-contained prompt with paths, error text and
decisions included; tell the sub-agent to read AGENTS.md first; give read-only
tasks read-only tools (Read/Grep/Glob, no Bash/Write); route to a cheap model via
frontmatter `model`. Custom agents live in `.claude/agents/` — prefer built-ins.

---

## Model usage

Claude Pro, 5-hour rolling window.

| Model | Use for |
|---|---|
| **Opus 5** | architecture and schema decisions, platform channel code (PhotoKit, MediaStore), ML pipeline integration, complex multi-file refactoring |
| **Sonnet 5** | UI widgets and screens, unit tests, small bugfixes, anything repetitive or well-defined |
| **Haiku 4.5** | quick questions, lookups, log digests |

---

## Session hygiene

New conversation per feature — long sessions re-process history and burn tokens
exponentially; `/compact` mid-session if one runs long. One focused task per
conversation. AGENTS.md carries the project context, so do not re-explain it.
Delegate read-heavy exploration so the main session receives only summaries.

---

## Session-start prompt

```text
You are working on SoloGallery, a Flutter photo app. Read AGENTS.md first —
especially Absolute rules, Test strategy and Definition of Done.
Current task: [DESCRIBE TASK HERE].
Save the plan to docs/plans/ and wait for approval before writing code.
```
