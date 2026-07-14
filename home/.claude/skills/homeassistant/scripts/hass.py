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

def cmd_call(args):
    base_url, token = resolve_config(args)
    if "." not in args.service:
        print("Service must be DOMAIN.SERVICE, e.g. light.turn_on", file=sys.stderr); return 1
    domain, service = args.service.split(".", 1)
    payload = {}
    if args.entity:
        payload["entity_id"] = [e.strip() for e in args.entity.split(",")]
    for kv in args.data or []:
        if "=" not in kv:
            print(f"Bad --data (need k=v): {kv}", file=sys.stderr); return 1
        k, v = kv.split("=", 1)
        payload[k] = parse_value(v)
    st, body = api("POST", base_url, token, f"/api/services/{domain}/{service}", payload)
    if st == 400:
        print(f"Bad service call (400): {body}", file=sys.stderr); return 1
    if st == 401:
        print("AUTH FAILED (401)", file=sys.stderr); return 2
    if st >= 300:
        print(f"Error {st}: {body}", file=sys.stderr); return 1
    # echo resulting state of each targeted entity
    for eid in payload.get("entity_id", []):
        s2, b2 = api("GET", base_url, token, "/api/states/" + eid)
        if isinstance(b2, dict):
            print(f"{eid} -> {b2.get('state')}")
    print(f"OK {args.service} ({len(payload.get('entity_id', []))} target(s))")
    return 0

def cmd_services(args):
    base_url, token = resolve_config(args)
    st, body = api("GET", base_url, token, "/api/services")
    if not isinstance(body, list):
        print(f"Unexpected response ({st})", file=sys.stderr); return 1
    for dom in sorted(body, key=lambda d: d["domain"]):
        if args.domain and dom["domain"] != args.domain:
            continue
        for name, meta in sorted(dom.get("services", {}).items()):
            desc = meta.get("name") or meta.get("description", "")
            print(f"{dom['domain']}.{name}  —  {desc}")
    return 0

def register_control(sub):
    c = sub.add_parser("call")
    c.add_argument("service", help="DOMAIN.SERVICE")
    c.add_argument("--entity", help="entity_id (comma-separated for multiple)")
    c.add_argument("--data", action="append", metavar="K=V")
    c.set_defaults(func=cmd_call)
    s = sub.add_parser("services")
    s.add_argument("--domain")
    s.set_defaults(func=cmd_services)

def _iso_hours_ago(n):
    return (datetime.now(timezone.utc) - timedelta(hours=n)).isoformat(timespec="seconds")

def cmd_history(args):
    base_url, token = resolve_config(args)
    ts = _iso_hours_ago(args.hours)
    path = f"/api/history/period/{ts}?filter_entity_id={args.entity_id}&minimal_response"
    st, body = api("GET", base_url, token, path)
    if not isinstance(body, list) or not body:
        print("(no history)"); return 0
    for point in body[0]:
        print(f"{point.get('last_changed','')}  {point.get('state','')}")
    return 0

def cmd_logbook(args):
    base_url, token = resolve_config(args)
    ts = _iso_hours_ago(args.hours)
    path = f"/api/logbook/{ts}"
    if args.entity:
        path += f"?entity={args.entity}"
    st, body = api("GET", base_url, token, path)
    if not isinstance(body, list):
        print(f"Unexpected response ({st})", file=sys.stderr); return 1
    for e in body:
        print(f"{e.get('when','')}  {e.get('name','')}: {e.get('message','')}")
    return 0

def cmd_template(args):
    base_url, token = resolve_config(args)
    st, body = api("POST", base_url, token, "/api/template", {"template": args.template})
    if st == 400:
        print(f"Template error (400): {body}", file=sys.stderr); return 1
    print(body)
    return 0

def register_query(sub):
    h = sub.add_parser("history")
    h.add_argument("entity_id"); h.add_argument("--hours", type=int, default=24)
    h.set_defaults(func=cmd_history)
    l = sub.add_parser("logbook")
    l.add_argument("--hours", type=int, default=24); l.add_argument("--entity")
    l.set_defaults(func=cmd_logbook)
    t = sub.add_parser("template")
    t.add_argument("template", help="Jinja template string")
    t.set_defaults(func=cmd_template)

_REGISTRARS = []  # each later task appends a register(sub) callable
_REGISTRARS.append(register_control)
_REGISTRARS.append(register_query)

if __name__ == "__main__":
    sys.exit(main())
