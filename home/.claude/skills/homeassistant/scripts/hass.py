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
