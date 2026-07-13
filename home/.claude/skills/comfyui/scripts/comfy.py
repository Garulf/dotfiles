#!/usr/bin/env python3
"""Drive a remote ComfyUI server through its HTTP API (stdlib only)."""

import argparse
import json
import mimetypes
import os
import sys
import time
import uuid
from pathlib import Path
import urllib.request
import urllib.parse
import urllib.error

DEFAULT_SERVER = "http://10.0.0.80:8188"

# Node types that expose model choices, mapped to their model input name.
MODEL_LOADERS = [
    ("CheckpointLoaderSimple", "ckpt_name"),
    ("LoraLoader", "lora_name"),
    ("VAELoader", "vae_name"),
    ("UNETLoader", "unet_name"),
    ("CLIPLoader", "clip_name"),
    ("ControlNetLoader", "control_net_name"),
    ("UpscaleModelLoader", "model_name"),
]


def resolve_server(args):
    server = getattr(args, "server", None) or os.environ.get("COMFYUI_URL") or DEFAULT_SERVER
    return server.rstrip("/")


def api_get(server, path, timeout=10):
    url = server + path
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            body = resp.read()
    except urllib.error.HTTPError:
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(
            f"error: cannot reach ComfyUI at {server} ({exc}); is the server running?",
            file=sys.stderr,
        )
        sys.exit(2)
    if not body:
        return {}
    return json.loads(body)


def api_post(server, path, payload=None, timeout=10):
    url = server + path
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
    except urllib.error.HTTPError:
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(
            f"error: cannot reach ComfyUI at {server} ({exc}); is the server running?",
            file=sys.stderr,
        )
        sys.exit(2)
    if not body:
        return {}
    return json.loads(body)


def _gib(value):
    try:
        return f"{float(value) / (1024 ** 3):.1f}"
    except (TypeError, ValueError):
        return "?"


def cmd_stats(args):
    server = resolve_server(args)
    data = api_get(server, "/system_stats")
    system = data.get("system", {})
    version = system.get("comfyui_version")
    if version:
        print(f"ComfyUI version: {version}")
    if system.get("os"):
        print(f"OS: {system['os']}")
    if system.get("python_version"):
        print(f"Python: {system['python_version']}")
    for device in data.get("devices", []):
        name = device.get("name", "unknown")
        free = _gib(device.get("vram_free"))
        total = _gib(device.get("vram_total"))
        print(f"device: {name} | VRAM {free} / {total} GiB free")
    return 0


def cmd_queue(args):
    server = resolve_server(args)
    data = api_get(server, "/queue")
    running = data.get("queue_running", [])
    pending = data.get("queue_pending", [])
    print(f"running: {len(running)}, pending: {len(pending)}")
    for entry in running:
        print(f"running  {entry[1]}")
    for entry in pending:
        print(f"pending  {entry[1]}")
    return 0


def cmd_interrupt(args):
    server = resolve_server(args)
    api_post(server, "/interrupt")
    print("interrupt sent")
    return 0


def _choices_from_spec(spec):
    """Return list of string choices from an input spec.

    Two wire formats coexist (even on one server): classic
    `[[choices...], {config}]` and newer `["COMBO", {"options": [choices...]}]`.
    """
    if not (isinstance(spec, list) and spec):
        return None
    if isinstance(spec[0], list):
        if all(isinstance(x, str) for x in spec[0]):
            return spec[0]
        return None
    if spec[0] == "COMBO" and len(spec) > 1 and isinstance(spec[1], dict):
        options = spec[1].get("options")
        if isinstance(options, list) and all(isinstance(x, str) for x in options):
            return options
    return None


def _filter_choices(choices, term):
    if not term:
        return choices
    term = term.lower()
    return [c for c in choices if term in c.lower()]


def cmd_models(args):
    server = resolve_server(args)
    term = args.search
    if args.type:
        data = api_get(server, "/object_info/" + urllib.parse.quote(args.type))
        node = data.get(args.type)
        if not node:
            print(f"error: node type {args.type} not found on server", file=sys.stderr)
            return 1
        inputs = {}
        inputs.update(node.get("input", {}).get("required", {}))
        inputs.update(node.get("input", {}).get("optional", {}))
        for name, spec in inputs.items():
            choices = _choices_from_spec(spec)
            if choices is None:
                continue
            choices = _filter_choices(choices, term)
            if not choices:
                continue
            print(f"{name}:")
            for c in choices:
                print(f"  {c}")
        return 0

    data = api_get(server, "/object_info")
    for node_type, input_name in MODEL_LOADERS:
        node = data.get(node_type)
        if not node:
            continue
        spec = node.get("input", {}).get("required", {}).get(input_name)
        if spec is None:
            spec = node.get("input", {}).get("optional", {}).get(input_name)
        choices = _choices_from_spec(spec) if spec is not None else None
        if not choices:
            continue
        choices = _filter_choices(choices, term)
        if not choices:
            continue
        print(f"## {node_type}")
        for c in choices:
            print(c)
    return 0


def cmd_nodes(args):
    server = resolve_server(args)
    data = api_get(server, "/object_info")
    names = sorted(data.keys())
    term = args.search.lower() if args.search else None
    for name in names:
        if term and term not in name.lower():
            continue
        print(name)
    return 0


def _download_output(server, out_dir, item):
    filename = item.get("filename")
    if not filename:
        return None
    params = urllib.parse.urlencode(
        {
            "filename": filename,
            "subfolder": item.get("subfolder", ""),
            "type": item.get("type", ""),
        }
    )
    url = server + "/view?" + params
    dest = Path(out_dir) / filename
    with urllib.request.urlopen(url, timeout=60) as resp:
        data = resp.read()
    dest.write_bytes(data)
    return str(dest)


def cmd_submit(args):
    server = resolve_server(args)
    with open(args.workflow, "r", encoding="utf-8") as fh:
        workflow = json.load(fh)

    if isinstance(workflow, dict) and isinstance(workflow.get("nodes"), list):
        print(
            'error: this is UI-export format; re-export with "Save (API format)" '
            "(see references/api.md)",
            file=sys.stderr,
        )
        return 1

    payload = {"prompt": workflow, "client_id": str(uuid.uuid4())}
    resp = api_post(server, "/prompt", payload)

    if resp.get("error") or resp.get("node_errors"):
        print("submission rejected:", file=sys.stderr)
        if resp.get("error"):
            print(json.dumps(resp["error"], indent=2), file=sys.stderr)
        if resp.get("node_errors"):
            print(json.dumps(resp["node_errors"], indent=2), file=sys.stderr)
        return 1

    prompt_id = resp.get("prompt_id")
    print(f"prompt_id: {prompt_id}")

    if not args.wait:
        print(f"not waiting; check later with: history {prompt_id}")
        return 0

    out_dir = args.out
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    deadline = time.time() + args.timeout
    entry = None
    while time.time() < deadline:
        hist = api_get(server, "/history/" + urllib.parse.quote(prompt_id))
        if prompt_id in hist:
            entry = hist[prompt_id]
            break
        time.sleep(2)

    if entry is None:
        print(f"error: timed out after {args.timeout}s waiting for {prompt_id}", file=sys.stderr)
        return 3

    status = entry.get("status", {})
    if status.get("status_str") == "error":
        print("workflow errored:", file=sys.stderr)
        for msg in status.get("messages", []):
            print(json.dumps(msg), file=sys.stderr)
        return 1

    saved = []
    for output in entry.get("outputs", {}).values():
        for key in ("images", "gifs", "videos", "audio"):
            for item in output.get(key, []):
                path = _download_output(server, out_dir, item)
                if path:
                    print(f"saved: {path}")
                    saved.append(path)

    if not saved:
        print("no downloadable outputs found in this result")
    return 0


def _output_filenames(entry):
    names = []
    for output in entry.get("outputs", {}).values():
        for key in ("images", "gifs", "videos", "audio"):
            for item in output.get(key, []):
                if item.get("filename"):
                    names.append(item["filename"])
    return names


def cmd_history(args):
    server = resolve_server(args)
    if args.prompt_id:
        data = api_get(server, "/history/" + urllib.parse.quote(args.prompt_id))
        entry = data.get(args.prompt_id)
        if not entry:
            print(f"no history for {args.prompt_id}")
            return 0
        print(json.dumps(entry.get("status", {}), indent=2))
        for name in _output_filenames(entry):
            print(f"output: {name}")
        return 0

    data = api_get(server, f"/history?max_items={args.limit}")
    for prompt_id, entry in data.items():
        status_str = entry.get("status", {}).get("status_str", "?")
        names = ", ".join(_output_filenames(entry)) or "(none)"
        print(f"{prompt_id}  [{status_str}]  {names}")
    return 0


def cmd_list_workflows(args):
    server = resolve_server(args)
    query = urllib.parse.urlencode({"dir": "workflows", "recurse": "true"})
    files = api_get(server, "/userdata?" + query)
    if not files:
        print("(no saved workflows)")
        return 0
    for name in files:
        print(name)
    return 0


def cmd_save_workflow(args):
    server = resolve_server(args)
    path = Path(args.workflow)
    body = path.read_bytes()
    json.loads(body)  # validate JSON before uploading

    name = args.name or path.name
    if not name.endswith(".json"):
        name += ".json"
    dest = urllib.parse.quote(f"workflows/{name}", safe="")
    overwrite = "true" if args.overwrite else "false"
    url = f"{server}/userdata/{dest}?overwrite={overwrite}"
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp.read()
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            print(
                f"error: workflows/{name} already exists; pass --overwrite to replace it",
                file=sys.stderr,
            )
            return 1
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(
            f"error: cannot reach ComfyUI at {server} ({exc}); is the server running?",
            file=sys.stderr,
        )
        sys.exit(2)
    print(f"saved: workflows/{name}")
    return 0


def cmd_upload(args):
    server = resolve_server(args)
    path = Path(args.file)
    filename = path.name
    content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
    boundary = uuid.uuid4().hex
    data = path.read_bytes()

    parts = []
    parts.append(f"--{boundary}\r\n".encode())
    parts.append(
        f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'.encode()
    )
    parts.append(f"Content-Type: {content_type}\r\n\r\n".encode())
    parts.append(data)
    parts.append(b"\r\n")
    if args.subfolder:
        parts.append(f"--{boundary}\r\n".encode())
        parts.append(b'Content-Disposition: form-data; name="subfolder"\r\n\r\n')
        parts.append(args.subfolder.encode())
        parts.append(b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    body = b"".join(parts)

    req = urllib.request.Request(
        server + "/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            resp_body = resp.read()
    except urllib.error.HTTPError:
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(
            f"error: cannot reach ComfyUI at {server} ({exc}); is the server running?",
            file=sys.stderr,
        )
        sys.exit(2)

    result = json.loads(resp_body) if resp_body else {}
    name = result.get("name", filename)
    subfolder = result.get("subfolder", "")
    if subfolder:
        print(f"name: {name}\nsubfolder: {subfolder}")
    else:
        print(f"name: {name}")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Drive a remote ComfyUI server via its HTTP API.")
    parser.add_argument("--server", help="ComfyUI base URL (overrides COMFYUI_URL env)")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("stats", help="show server version and VRAM").set_defaults(func=cmd_stats)
    sub.add_parser("queue", help="show running/pending jobs").set_defaults(func=cmd_queue)
    sub.add_parser("interrupt", help="interrupt the current job").set_defaults(func=cmd_interrupt)

    p_models = sub.add_parser("models", help="list installed model choices")
    p_models.add_argument("--type", help="inspect one node type's model inputs")
    p_models.add_argument("--search", help="case-insensitive filter on choices")
    p_models.set_defaults(func=cmd_models)

    p_nodes = sub.add_parser("nodes", help="list node class names")
    p_nodes.add_argument("--search", help="case-insensitive substring filter")
    p_nodes.set_defaults(func=cmd_nodes)

    p_submit = sub.add_parser("submit", help="submit an API-format workflow")
    p_submit.add_argument("workflow", help="path to API-format workflow JSON")
    p_submit.add_argument("--wait", action="store_true", help="wait and download outputs")
    p_submit.add_argument("--timeout", type=int, default=600, help="wait timeout in seconds")
    p_submit.add_argument("--out", default=".", help="output directory for downloads")
    p_submit.set_defaults(func=cmd_submit)

    p_history = sub.add_parser("history", help="show job history/outputs")
    p_history.add_argument("prompt_id", nargs="?", help="specific prompt id")
    p_history.add_argument("--limit", type=int, default=5, help="max recent items")
    p_history.set_defaults(func=cmd_history)

    p_lw = sub.add_parser("list-workflows", help="list workflows saved on the server")
    p_lw.set_defaults(func=cmd_list_workflows)

    p_sw = sub.add_parser("save-workflow", help="save a workflow file to the server's UI library")
    p_sw.add_argument("workflow", help="path to workflow JSON (UI-export format for UI use)")
    p_sw.add_argument("--name", help="destination filename (default: source filename)")
    p_sw.add_argument("--overwrite", action="store_true", help="replace an existing workflow")
    p_sw.set_defaults(func=cmd_save_workflow)

    p_upload = sub.add_parser("upload", help="upload an image for LoadImage")
    p_upload.add_argument("file", help="path to image file")
    p_upload.add_argument("--subfolder", help="destination subfolder")
    p_upload.set_defaults(func=cmd_upload)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except urllib.error.HTTPError as exc:
        try:
            excerpt = exc.read().decode("utf-8", "replace")[:500]
        except Exception:
            excerpt = ""
        print(f"error: HTTP {exc.code} {exc.reason}\n{excerpt}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
