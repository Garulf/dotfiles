---
name: comfyui
description: Use when generating images or video, running/building/installing ComfyUI workflows, installing models onto the server, or checking on the ComfyUI server (queue, checkpoints, LoRAs, samplers, VRAM) at 10.0.0.80.
---

# Remote ComfyUI

Overview: A personal ComfyUI server runs at `http://10.0.0.80:8188` (override with the `COMFYUI_URL` env var or the `--server` flag). All interaction goes through `scripts/comfy.py`, a stdlib-only script run with `python3`.

## Workflow

1. Check reachability: `python3 ~/.claude/skills/comfyui/scripts/comfy.py stats`. If it times out, the machine is probably powered off — tell the user; do not debug networking.
2. Discover what's installed before building anything: `comfy.py models` (checkpoints/LoRAs/VAEs), `comfy.py nodes --search ltx` (or `wan`, `svd`, `animatediff`) for video nodes. Never trust model names in templates — substitute real installed ones.
3. Build the workflow: copy a template (`references/workflows/txt2img.json`, `img2img.json`, or `video-t2v.json`) or use user-provided API-format JSON; replace every `PLACEHOLDER_*` string with discovered values and edit node inputs per the request (set a random KSampler `seed` unless reproducing a result). Format details: `references/api.md`. For the prompt text itself — composition, lighting, lens, palette, and style vocabulary — use the `visual-craft` skill (`~/.claude/skills/visual-craft/`).
4. Submit and wait: `comfy.py submit wf.json --wait --out OUTDIR` — downloads all outputs when finished.
5. Send the resulting files to the user.

## Quick reference

| Command | Purpose |
| --- | --- |
| `stats` | Server version and VRAM free/total |
| `queue` | Running and pending job counts and ids |
| `interrupt` | Interrupt the current job |
| `models [--type NODE]` | List installed model choices (all loaders, or one node) |
| `nodes --search TERM` | List node class names, filtered |
| `submit FILE --wait --out DIR` | Submit workflow, wait, download outputs |
| `history [ID]` | Recent jobs, or one job's status and outputs |
| `upload FILE` | Upload an image; prints the name for a LoadImage node |
| `list-workflows` | List workflows saved in the server's UI library |
| `save-workflow FILE [--name N] [--overwrite]` | Save a workflow into the server's UI library |

Run `--help` on any subcommand for its flags.

## Video

Video workflows depend entirely on which custom nodes are installed (LTX, WAN, SVD, AnimateDiff, VHS, …). Always discover first with `comfy.py nodes --search <term>` and `comfy.py models --type <FoundLoaderNode>` — do not build from memory. `references/workflows/video-t2v.json` is only a structural sketch, not runnable. Outputs (mp4/webp/gif) download the same way via `submit --wait`.

## Installing workflows

To make a workflow show up in the server's UI Workflows sidebar: `comfy.py save-workflow FILE`. The sidebar expects **UI-export** JSON (top-level `"nodes"` list) — the opposite of `submit`, which needs API format. Workflows only run via `submit` don't need installing at all. Details: `references/api.md`.

## Installing models

Model downloads go through the ComfyUI-Manager custom node's API — probe for it first (`curl $SERVER/manager/version`), find the model in Manager's list, queue the install, then confirm with `comfy.py models --search <name>`. Full procedure and gotchas (security level, models outside Manager's list): `references/api.md`. That section is marked unverified — validate the endpoints against the live server on first use.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| UI-export JSON submitted (has a `"nodes"` list) | Re-export with Save (API format); `comfy.py` detects and rejects it |
| Hardcoded template model names | Query `models` first and substitute installed names |
| `submit` without `--wait`, then reading empty history | Use `--wait`, or poll `history <id>` |
| Building a video workflow from memory | Discover installed nodes first |
| API-format JSON saved with `save-workflow` for UI use | The UI sidebar wants UI-export format; API format is for `submit` |
| Assuming Manager model-install endpoints from memory | Probe `/manager/version` and follow api.md, verifying as you go |
