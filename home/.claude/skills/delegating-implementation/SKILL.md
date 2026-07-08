---
name: delegating-implementation
description: Use when implementing a feature, refactor, or multi-file code change, before writing any implementation code in the main session. Applies whenever the main session runs on a high-capability model (Fable/Mythos) and the change involves creating or editing product code.
---

# Delegating Implementation

## Overview

Split work by cost: the expensive model (this session) does the thinking — spec and implementation plan — and cheap Opus-at-low-effort subagents do the typing. The quality of the result is decided by the spec, not by who writes the code.

**Core principle: if a task needs judgment, it isn't specced enough to dispatch yet.**

## When to Use

- Any feature, bugfix, or refactor that creates or edits code
- Especially multi-file changes or several independent tasks (dispatch in parallel)

**When NOT to use:**
- Trivial edits (a few lines, one file) — dispatch overhead exceeds the typing
- Debugging or exploration — unknowns mean judgment, keep it in the main session
- The user asked you to write the code directly

## Workflow

1. **Spec in main session.** Read the relevant code yourself. Produce a spec: exact file paths, function/type signatures, behavior including edge cases, and how to verify (test command, expected outcome). Every design decision gets made here.
2. **Split into self-contained tasks.** Each task must be completable without seeing the others' output. Sequential dependencies → one bigger task or ordered dispatches.
3. **Dispatch each task to the `opus-implementer` agent** (Agent tool, `subagent_type: "opus-implementer"`). If that agent type is missing, recreate `~/.claude/agents/opus-implementer.md` with frontmatter `model: opus`, `effort: low` — but note agent definitions load at session start, so a just-created file is only visible to new sessions.
4. **Review and verify in main session.** Read the diff, run the tests/build yourself. Fix problems by re-dispatching with a corrected spec (via SendMessage to the same agent, so it keeps context). Only edit directly when the fix is smaller than explaining it.

## Dispatch Prompt Recipe

A dispatch prompt consists of, in order:

1. **Goal** — one sentence: what exists after this task that didn't before.
2. **Files** — every path to create or modify.
3. **Spec** — signatures, behavior, edge cases; code skeletons where structure matters. Include the relevant excerpts of existing code the agent needs to conform to (it starts cold).
4. **Out of scope** — what it must not touch.
5. **Verification** — exact commands to run and what passing looks like.

If you catch yourself writing "choose whichever seems best" or "handle errors appropriately" in a dispatch prompt, that decision belongs in step 1 — make it, then state it.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Writing the implementation yourself "since you're already looking at the file" | Spec it and dispatch; only trivial few-line edits are exempt |
| Vague dispatch prompt, letting the subagent design | Low-effort Opus executes well but designs poorly — decide everything in the spec |
| Trusting the subagent's "done" report | It reports; you verify. Read the diff, run the tests in the main session |
| Fixing subagent output by hand-editing at length | Re-dispatch with a corrected spec; hand-edit only when the fix is smaller than explaining it |
| Serial dispatch of independent tasks | Independent tasks go out in parallel in one message |
