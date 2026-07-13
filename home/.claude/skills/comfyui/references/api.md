# ComfyUI HTTP API reference

The server exposes a plain HTTP API. `scripts/comfy.py` uses only these endpoints.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/system_stats` | Server version, OS, python, per-device VRAM |
| GET | `/queue` | Running and pending jobs |
| POST | `/interrupt` | Interrupt the currently running job |
| POST | `/prompt` | Submit a workflow for execution |
| GET | `/history` | Recent completed jobs (`?max_items=N`) |
| GET | `/history/{id}` | One job's status and outputs |
| GET | `/view` | Download an output file (`?filename=&subfolder=&type=`) |
| POST | `/upload/image` | Upload an image (multipart, field `image`) |
| GET | `/object_info` | All node classes and their input/output specs |
| GET | `/object_info/{class}` | One node class's spec |
| GET | `/userdata?dir=workflows&recurse=true` | List workflows saved in the user's UI library |
| POST | `/userdata/workflows%2F{name}.json?overwrite=true` | Save a workflow file (raw JSON body); 409 if it exists and `overwrite=false` |
| WS | `/ws` | Live progress events (websocket). The helper polls `/history` instead — simpler and sufficient. |

## API-format workflow JSON

An API-format workflow is a top-level dict mapping a node id (a string integer) to a node object:

```json
{
  "3": {
    "class_type": "KSampler",
    "inputs": { "seed": 0, "model": ["4", 0] },
    "_meta": { "title": "KSampler" }
  },
  "4": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": { "ckpt_name": "some.safetensors" },
    "_meta": { "title": "Load Checkpoint" }
  }
}
```

- Literal inputs are plain values (numbers, strings, booleans).
- Connections are `["<source_node_id>", <output_index>]` — a reference to another node's output slot.
- `_meta.title` is a human label and is optional.

## Getting API format from the UI

The default "Save" in the UI produces a **UI-export** file (a dict with a top-level `"nodes"` list) which the `/prompt` endpoint cannot run. To get API format:

1. Enable Settings → **Enable dev mode options** ("Dev mode").
2. Use the workflow menu's **Save (API format)**. On newer frontends this is **Export (API)**.

`comfy.py submit` detects UI-export files (top-level `"nodes"` list) and refuses them.

## /prompt request and response

Request:

```json
{ "prompt": { ...workflow... }, "client_id": "<uuid>" }
```

Success:

```json
{ "prompt_id": "abc-123", "number": 5, "node_errors": {} }
```

Validation failure includes an `error` object and a non-empty `node_errors` map describing which node inputs are invalid.

## /history/{id} shape

```json
{
  "abc-123": {
    "prompt": [ ... ],
    "outputs": {
      "7": { "images": [ { "filename": "out_0001.png", "subfolder": "", "type": "output" } ] }
    },
    "status": {
      "status_str": "success",
      "completed": true,
      "messages": [ ... ]
    }
  }
}
```

`status_str` is `"success"` or `"error"`. Output collections also appear under `gifs`, `videos`, and `audio` for non-image outputs; each item has `filename`, `subfolder`, and `type` for the `/view` download.

## /object_info shape

Each node class maps to:

```json
{
  "input": { "required": { ... }, "optional": { ... } },
  "output": [ ... ]
}
```

An input spec is `[TYPE_OR_CHOICES, {config}]`. Choice inputs come in **two wire formats, both present on the same server** (verified 2026-07-13): classic — first element is a **list of strings** (the valid choices) — and newer — first element is the string `"COMBO"` with the choices in `{config}.options`. This is how installed checkpoints, LoRAs, VAEs, samplers, etc. are discovered; `comfy.py models` handles both formats.

## Installing workflows into the UI library

`comfy.py save-workflow FILE` writes to the server's user workflow directory (`user/default/workflows/`) via the `/userdata` endpoint, making it appear in the UI's Workflows sidebar.

**Format matters:** the UI sidebar expects **UI-export** JSON (top-level `"nodes"` list) — the opposite of what `/prompt` wants. An API-format file saved there is at best awkward to open in the UI. So:

- Workflow destined for the UI sidebar → save the UI-export file.
- Workflow destined for execution via `comfy.py submit` → keep API format locally (or in `references/workflows/`); no server install needed.

The subdirectory path is URL-encoded into the filename segment (`workflows%2Fname.json`), not passed as separate path components.

## Installing models (ComfyUI-Manager)

> **Endpoint paths are version-dependent — probe first.** Verified 2026-07-11 against **ComfyUI-Manager V4.2.1** (the `comfyui_manager` pip package bundled with ComfyUI Desktop, enabled via `--enable-manager`). This version prefixes everything with **`/v2/`** and mirrors it under `/api/`. Older Managers used unversioned `/manager/...`. So probe `GET /v2/manager/version` first; if that 404s, try `GET /manager/version`. A plain 404 on *both* while the server otherwise responds means an older/newer path scheme — grep the running package for route defs (`Select-String routes\.(get|post) …\comfyui_manager\**\*.py`) rather than guessing.
>
> Note: on **ComfyUI Desktop**, Manager is the `comfyui_manager` **pip package**, not a `custom_nodes/ComfyUI-Manager` folder. Dropping a copy into `custom_nodes` gets **"Blocked by policy"** and ignored — don't bother installing it there.

Model downloads go through Manager's HTTP API; core ComfyUI has no model-download endpoint.

> **V4.2.2 (verified 2026-07-13) changed the API.** `GET /v2/externalmodel/getlist` and `GET /v2/customnode/getlist` are **gone** (404), `/v2/customnode/fetch_updates` returns 410, and `POST /v2/manager/queue/install` never existed here. Everything goes through the generic task queue. When in doubt, download the matching release tarball from `github.com/Comfy-Org/ComfyUI-Manager` and grep `comfyui_manager/glob/manager_server.py` for `@routes.` — don't guess.

1. **Model installs:** `POST /v2/manager/queue/install_model` still exists (model entry dict as JSON body).
2. **Custom node installs:** `POST /v2/manager/queue/task` with body `{"ui_id": "<any-id>", "client_id": "<any>", "kind": "install", "params": {"id": "<author/repo or registry name>", "version": "nightly", "selected_version": "nightly", "repository": "<github url>", "mode": "cache", "channel": "default", "skip_post_install": false}}` (`selected_version` may also be `latest` or a semver for registry packs). Schema: `comfyui_manager/data_models/generated_models.py` (`QueueTaskItem`, `InstallPackParams`).
3. **Start and watch:** `POST /v2/manager/queue/start`, poll `GET /v2/manager/queue/status` → `{"total_count","done_count","in_progress_count","pending_count","is_processing"}`, then `GET /v2/manager/queue/history` for per-task results.
4. **Confirm:** `comfy.py models --search <name>` / `comfy.py nodes --search <ClassName>`.

Still-working related routes: `GET /v2/customnode/installed`, `GET /v2/customnode/getmappings?mode=cache` (pack name → node class names; use it to check a repo is known to Manager), `POST /v2/manager/queue/update_comfyui`, `POST /v2/manager/reboot` (connection resets mid-request = it worked; poll `stats` until back, ~30–60 s).

**Gotchas:**
- **Custom-node installs are hard-blocked when the server listens on the LAN.** `do_install` requires security level `middle+`, which passes only if the server listens on loopback or `network_mode=personal_cloud` — the *client's* address is irrelevant, so no config short of relaxing security allows API installs on this server (it listens on 0.0.0.0). The task completes with a bare `"result": "failed"` and no message; that's the security gate. Don't relax the setting — install over SSH instead: the ComfyUI host is the `albedo` SSH alias (Windows, cmd.exe); `git clone` into the **running instance's** custom_nodes, then `POST /v2/manager/reboot`.
- **Find the live base directory before touching files.** albedo has multiple ComfyUI installs; the old Desktop `config.json` basePath (`Documents\ComfyUI`) is stale. Get the truth from the running process: `tasklist /FI "IMAGENAME eq python.exe"`, then `powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"ProcessId=<pid>\").CommandLine"` and read `--base-directory`. As of 2026-07-13 it is `C:\Users\Garulf\ComfyUI-Installs\ComfyUI (Copy)\ComfyUI`.
- Models **not** in Manager's curated list can still be installed by passing a model entry dict with an explicit `url`/`save_path`/`filename` to `install_model` (e.g. a Hugging Face file), subject to the security level; otherwise the fallback is asking the user to place the file in the right `models/` subdirectory on the server (again: the live instance's models dir / `shared_model_paths.yaml`, not the stale Desktop path).

## Template placeholder convention

The templates in `references/workflows/` use placeholders like `PLACEHOLDER_CHECKPOINT`, `PLACEHOLDER_POSITIVE_PROMPT`, and `PLACEHOLDER_UPLOADED_IMAGE`. Every placeholder MUST be replaced with a real value discovered from the live server (via `comfy.py models` / `nodes` / `upload`) before submitting.
