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

## ComfyUI Desktop instances on albedo

The server machine (`albedo`, SSH host) runs **Comfy Desktop 2**–managed instances. Do NOT invent launch commands — read the instance's real config and replicate it.

**Find them:** `%APPDATA%\Comfy Desktop\installations.json` lists every instance (id, name, `installPath`, `adoptedPythonPath`, `launchArgs`, `useSharedModels`, `useSharedInputOutput`). `%APPDATA%\Comfy Desktop\settings.json` holds the shared paths (`modelsDirs`, `inputDir`, `outputDir`). An install dir with a `.comfyui-desktop-2` marker file is Desktop-managed; its `.launcher\snapshots\` records custom-node state and its `logs\comfyui.log` shows what config actually loaded last run.

**Known instances (2026-07-14):**

| Name | Where | Role |
| --- | --- | --- |
| ComfyUI (Server) | `C:\Users\Garulf\ComfyUI-Installs\ComfyUI (Copy)` | THE generation server — launchArgs `--port 8188 --enable-manager --listen 0.0.0.0`, shared models + shared I/O |
| ComfyUI | `C:\Users\Garulf\ComfyUI-Installs\ComfyUI` | Primary desktop install (per-install I/O under `Documents\ComfyUI`) |
| ComfyUI (Client) / Comfy Cloud | remote entries | Not local servers; ignore |

**Shared paths (settings.json):** models = `F:\Stable Diffusion\models` + 3 more dirs via the Desktop-generated yaml `%APPDATA%\Comfy Desktop\shared_model_paths.yaml`; input = `D:\Users\Garulf\Documents\ComfyUI\input`; output = `D:\Users\Garulf\Documents\ComfyUI\output`. Files placed for `LoadImage` must go under the **D: input dir**, not the install's local `input\` folder.

**Launch an instance headless over SSH** (verified; replicates Desktop exactly — Desktop appends the shared-yaml and I/O args to the instance's `launchArgs`):

```
cd /d "<installPath>\ComfyUI" && set PYTHONUTF8=1&& .venv\Scripts\python.exe main.py <launchArgs> --extra-model-paths-config "C:\Users\Garulf\AppData\Roaming\Comfy Desktop\shared_model_paths.yaml" --input-directory D:\Users\Garulf\Documents\ComfyUI\input --output-directory D:\Users\Garulf\Documents\ComfyUI\output
```

Run it via a persistent background ssh (`Start-Process` detach dies silently through ssh; schtasks is blocked by the auto-mode classifier). Do not pass a hand-rolled model-paths yaml or output flag that contradicts the Desktop settings — the user's configuration is authoritative. After launch, verify: `stats`, a LoRA listing, `nodes --search Krea2Edit` (instance custom nodes), and `curl /api/v2/manager/version`.

**Headless launch MUST set `TQDM_DISABLE=1` and redirect output to a log file** — over SSH there's no real console, so ComfyUI-Manager's tqdm progress writer crashes **every KSampler run** with `OSError [Errno 22] Invalid argument` (traceback ends in `comfyui_manager/prestartup_script.py` `write_stderr`). Sampling never completes. The fix is baked into the launch: prepend `set TQDM_DISABLE=1&&` and append `> D:\Users\Garulf\Documents\ComfyUI\comfy_headless.log 2>&1` to the command above (that log path is also where you read startup + detection errors). Verified 2026-07-14.

**Operating / restarting a running instance:**

- **Find it:** `Get-CimInstance Win32_Process -Filter "name='python.exe'" | Where-Object { $_.CommandLine -like '*main.py*8188*' } | Select ProcessId,CreationDate`. The server runs as **two** python PIDs (parent + child) — kill both.
- **Restart = kill + relaunch.** ComfyUI-Manager's `/api/manager/reboot` did **not** actually restart the headless instance (server stayed up, config unchanged — verify a real restart by watching the port go *down* then up; a 6 s "back up" means it never rebooted). Reliable path: `taskkill /F /PID <both>` then re-run the headless launch command (background ssh). Killing a server the agent didn't start can trip the auto-mode classifier — the user can approve.
- **A running server caches model paths from startup.** Editing the yaml or moving models has **no effect until restart**.

**Model roots — `settings.json` is the source of truth; the yaml is generated from it.** `%APPDATA%\Comfy Desktop\settings.json` holds `modelsDirs` (a JSON list of model roots), `inputDir`, `outputDir`, `installDir`. Comfy Desktop **regenerates** `shared_model_paths.yaml` (one `comfy.desktop_N:` block per `modelsDirs` entry, each mapping `loras:`, `ultralytics:`, …) from `settings.json`. So:
- **Durable change** (add/remove a model root): edit `settings.json` `modelsDirs`. A yaml-only edit is overwritten next time Desktop runs.
- **Immediate effect on a running headless instance**: the server reads the *yaml* at startup and won't see `settings.json` changes until the yaml regenerates — so also edit the yaml and restart (or launch via Desktop to regenerate it). Best practice: fix `settings.json` **and** the yaml, then restart. Keep a `.bak` of each.

**Missing-root gotcha:** if any registered root is **deleted or missing**, model loads fail at node validation with `[WinError 3] The system cannot find the path specified: '...\models\loras'` (e.g. `LoraLoaderModelOnly` → `prompt_outputs_failed_validation`) — because the server registered that path at startup and now can't scan it. Fix per above (drop the dead entry from `settings.json` + yaml, restart), or restore the directory. After restart, confirm with the log: `Select-String 'Adding extra search path loras'` should list only existing roots.

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
