---
name: tmux-driver
description: Drive tmux sessions to run, monitor, and interact with long-running or interactive processes without blocking. Use this whenever a command would tie up the shell or outlive the current step — dev servers, builds, test suites, tail -f / log watching, installers or CLIs that prompt for input, REPLs, SSH sessions that must persist, or anything the user asks to "run in the background", "keep running", "check on later", or "run in tmux". Also use it to inspect or send input to tmux sessions that already exist.
---

# Driving tmux

tmux lets you run processes in detached sessions that survive after your shell command returns. Instead of blocking on a long command or losing a dev server when the step ends, you start it in tmux, keep working, and check on it whenever you want. You never attach — everything is done with one-shot `tmux` commands (as an agent you have no terminal to attach with).

## Targeting syntax (read this first — it's a common trap)

Exact-name matching differs by command type on tmux 3.x:

- Session commands (`has-session`, `kill-session`, `new-session`): `-t "=name"`
- Pane commands (`send-keys`, `capture-pane`, `display-message`, `pipe-pane`): `-t "=name:"` — the **trailing colon is required**; `-t "=name"` fails with "can't find pane".

Always use the `=` exact form. Without it tmux prefix-matches, so `claude-dev` could resolve to `claude-devserver` and you'd type into the wrong pane.

## Ground rules

- **Use your own sessions, prefixed `claude-`** (e.g. `claude-build`, `claude-devserver`). Never kill, restart, or send keys to a session you didn't create unless the user explicitly asks — their sessions may hold live work. `tmux ls` shows what exists.
- **Create sessions wide**: `-x 220 -y 50`. Narrow default panes hard-wrap long lines, which mangles captured output.
- **Never send a command into a busy pane.** Keystrokes go into the running program's stdin, not a shell. Check idleness first (see below) or use a fresh session — sessions are cheap.
- **Clean up when done**: `tmux kill-session -t "=claude-build"` once a task is finished. Leave anything the user wants running.

## The common case: run a command and wait for it

Use the bundled script instead of hand-rolling polling:

```bash
scripts/tmux-run.sh <session> <timeout-seconds> '<command>'
# e.g.
scripts/tmux-run.sh claude-build 600 'cargo build --release'
```

It creates the session if needed, refuses if the pane is busy (exit 3), runs the command, and waits up to the timeout. On completion it prints only that command's output and exits with the command's real exit code. On timeout it exits 124 and the command **keeps running** — check on it later with `capture-pane`. This makes long builds/tests safe: pick a generous timeout, and even if it fires, nothing is lost.

## Fire-and-forget: servers and watchers

For processes meant to keep running (dev servers, `tail -f`, `npm run dev`):

```bash
tmux new-session -d -s claude-devserver -x 220 -y 50
tmux send-keys -t "=claude-devserver:" -l 'npm run dev'
tmux send-keys -t "=claude-devserver:" Enter
sleep 3   # give it a moment to start (longer for slow servers)
tmux capture-pane -t "=claude-devserver:" -p -J | tail -30   # verify it came up
```

Then continue with other work and re-capture whenever you need current output.

## Reading output

```bash
tmux capture-pane -t "=claude-devserver:" -p -J           # visible screen
tmux capture-pane -t "=claude-devserver:" -p -J -S -      # entire scrollback
tmux capture-pane -t "=claude-devserver:" -p -J -S -200   # last 200 lines of history
```

`-p` prints to stdout, `-J` joins wrapped lines. Captures include the shell prompt lines and trailing blank rows — match on the program's text, don't parse the whole capture. Avoid `-e` (embeds ANSI color escapes) unless you need them. For very chatty processes, log continuously instead of repeatedly capturing:

```bash
tmux pipe-pane -t "=claude-devserver:" -o 'cat >> /tmp/devserver.log'
```

## Sending input (interactive prompts, REPLs, TUIs)

Send text **literally** with `-l`, then send `Enter` as a separate call — this sidesteps quoting/escaping bugs entirely:

```bash
tmux send-keys -t "=claude-repl:" -l 'print("hello")'
tmux send-keys -t "=claude-repl:" Enter
```

Special keys use tmux key names (no `-l`): `Enter`, `Escape`, `Tab`, `Space`, `Up`, `Down`, `Left`, `Right`, `PageUp`, `C-c` (interrupt), `C-d` (EOF), `C-z`. Answering an installer prompt is `send-keys -l 'y'` + `Enter`; navigating a TUI menu is `Down`/`Enter`. After each input, `capture-pane` to see how the program responded before sending more — drive it like a conversation, not a script.

## Is it still running? Is the pane idle?

```bash
tmux display-message -t "=claude-build:" -p '#{pane_current_command}'
```

If this prints an external program (`cargo`, `node`, `python`), it's still running. If it prints a shell (`bash`, `zsh`, `sh`), the pane is *usually* idle — but a shell **script** or builtin (`read` prompting for input) also reports the shell name. When it says shell but you're unsure, `capture-pane` and check whether the last non-blank line is a prompt or a question awaiting input. To interrupt whatever runs: `tmux send-keys -t "=claude-build:" C-c`.

## Quick reference

```bash
tmux ls                                    # list sessions (exits 1 if server not running — that's fine)
tmux has-session -t "=name" 2>/dev/null    # exit 0 if session exists
tmux new-session -d -s name -x 220 -y 50   # create detached
tmux kill-session -t "=name"               # destroy
tmux new-window -t "=name:" -n logs        # extra window; target it as "=name:logs"
```

## Gotchas

- **`$TMUX` set in your own environment** means you're already inside a tmux pane. You can still manage other sessions normally with one-shot commands; just never `tmux attach`.
- **A session's shell is the user's login shell** with their dotfiles loaded — aliases, PATH, and environment may differ from your non-interactive shell. If a command behaves differently in tmux, that's usually why.
- **Environments differ.** tmux lives at different paths per machine (Homebrew on macOS, apt on Ubuntu, pkg on Termux, nix profile on NixOS) — invoke plain `tmux` from PATH and check `command -v tmux` before assuming it exists. On Windows, tmux only exists inside WSL.
- **Sockets are per-user.** If a session "disappears", you may be a different user (sudo, ssh) talking to a different tmux server (`/tmp/tmux-<uid>/`).
