#!/usr/bin/env python3
"""Home Assistant REST API CLI (stdlib only)."""
import json, os, sys
import urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")

class ConfigError(Exception): pass
class ConnError(Exception): pass

def _load_config_file():
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {}

def resolve_config(args):
    cfg = None
    url = getattr(args, "url", None) or os.environ.get("HA_URL")
    token = getattr(args, "token", None) or os.environ.get("HA_TOKEN")
    if not url or not token:
        cfg = _load_config_file()
        url = url or cfg.get("url")
        token = token or cfg.get("token")
    if not url or not token:
        raise ConfigError(
            "No Home Assistant URL/token found. Set HA_URL and HA_TOKEN env vars, "
            "pass --url/--token, or create config.json (see config.example.json)."
        )
    return url.rstrip("/"), token

def parse_value(raw):
    low = raw.lower()
    if low == "true":  return True
    if low == "false": return False
    try: return int(raw)
    except ValueError: pass
    try: return float(raw)
    except ValueError: pass
    if raw[:1] in "[{":
        try: return json.loads(raw)
        except ValueError: pass
    return raw

def api(method, base_url, token, path, payload=None, timeout=10):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(base_url + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return resp.status, _maybe_json(body)
    except urllib.error.HTTPError as e:
        return e.code, _maybe_json(e.read().decode(errors="replace"))
    except (urllib.error.URLError, TimeoutError) as e:
        raise ConnError(str(e))

def _maybe_json(text):
    try: return json.loads(text)
    except ValueError: return text

def _short(base_url, token, entity):
    st, body = api("GET", base_url, token, "/api/states/" + entity)
    return st, body

def cmd_ping(args):
    base_url, token = resolve_config(args)
    try:
        st, body = api("GET", base_url, token, "/api/", timeout=5)
    except ConnError as e:
        print(f"UNREACHABLE: {base_url} ({e})", file=sys.stderr); return 2
    if st == 401:
        print("AUTH FAILED (401): token rejected", file=sys.stderr); return 2
    msg = body.get("message") if isinstance(body, dict) else body
    print(f"OK {base_url} — {msg}")
    return 0

def cmd_states(args):
    base_url, token = resolve_config(args)
    if args.entity_id:
        st, body = api("GET", base_url, token, "/api/states/" + args.entity_id)
        if st == 404:
            print(f"Unknown entity: {args.entity_id}", file=sys.stderr); return 1
        print(json.dumps(body, indent=2)); return 0
    st, body = api("GET", base_url, token, "/api/states")
    if not isinstance(body, list):
        print(f"Unexpected response ({st}): {body}", file=sys.stderr); return 1
    rows = []
    for e in body:
        eid = e["entity_id"]
        fn = e.get("attributes", {}).get("friendly_name", "")
        if args.domain and not eid.startswith(args.domain + "."):
            continue
        if args.filter and args.filter.lower() not in (eid + " " + fn).lower():
            continue
        rows.append((eid, str(e.get("state", "")), fn))
    w = max((len(r[0]) for r in rows), default=0)
    for eid, state, fn in sorted(rows):
        print(f"{eid:<{w}}  {state:<12}  {fn}")
    print(f"\n{len(rows)} ent  (of {len(body)})")
    return 0

def build_parser():
    import argparse
    p = argparse.ArgumentParser(prog="hass", description="Home Assistant REST CLI")
    p.add_argument("--url"); p.add_argument("--token")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("ping").set_defaults(func=cmd_ping)
    s = sub.add_parser("states")
    s.add_argument("entity_id", nargs="?")
    s.add_argument("--domain"); s.add_argument("--filter")
    s.set_defaults(func=cmd_states)
    return p, sub

def main(argv=None):
    p, sub = build_parser()
    # later tasks call register_*(sub) here
    for reg in _REGISTRARS:
        reg(sub)
    args = p.parse_args(argv)
    try:
        return args.func(args)
    except ConfigError as e:
        print(str(e), file=sys.stderr); return 2
    except ConnError as e:
        print(f"UNREACHABLE: {e}", file=sys.stderr); return 2

_REGISTRARS = []  # each later task appends a register(sub) callable

if __name__ == "__main__":
    sys.exit(main())
