---
name: homeassistant
description: Use when controlling or querying the user's Home Assistant smart home — turning devices on/off or setting them (lights, switches, climate, media players), reading sensor/entity state or history, discovering entities/services, or managing automations, scenes, scripts, and HA config/admin (reload, restart). Use whenever the user refers to "Home Assistant", "HA", "the smart home", or names a room/device that likely maps to an HA entity, even without saying "Home Assistant".
---

# Home Assistant

All interaction goes through `scripts/hass.py`, a stdlib-only Python 3 CLI hitting the HA
REST API. Credentials resolve from `--url`/`--token` flags → `HA_URL`/`HA_TOKEN` env vars →
`config.json` in this skill dir (copy `config.example.json`).

## Workflow

1. **Check reachability first:** `python3 ~/.claude/skills/homeassistant/scripts/hass.py ping`.
   If it reports UNREACHABLE, the HA box is probably off — tell the user; do not debug networking.
2. **Find the entity before acting:** `hass.py states --domain light` or
   `hass.py states --filter kitchen`. Never guess an `entity_id`; substring-match to find it.
3. **Discover the service/fields if unsure:** `hass.py services --domain light`.
4. **Act:** `hass.py call light.turn_on --entity light.kitchen --data brightness_pct=50`.
   `call` echoes each target's resulting state so you can confirm the effect.
5. **For automations/admin,** use the `automation`/`scene`/`script`/`config` subcommands.

## Guarded actions

`restart` and `automation set` (which overwrites an automation) refuse unless given `--yes`.
Confirm with the user *before* re-running with `--yes`.

## Quick reference

| Command | Purpose |
| --- | --- |
| `ping` | Reachability + HA version |
| `states [--domain D] [--filter S] [ENTITY_ID]` | List/filter entities, or dump one entity's full state+attributes |
| `call DOMAIN.SERVICE --entity X [--data k=v …]` | Call any service; echoes resulting state |
| `services [--domain D]` | Discover services and their fields |
| `history ENTITY_ID [--hours N]` | Entity state history |
| `logbook [--hours N] [--entity X]` | Human-readable event log |
| `template '{{ … }}'` | Render a Jinja template server-side |
| `automation list\|get\|set\|trigger\|reload` | Manage automations (`set`/`get` use the config API; `set` needs `--file` + `--yes`) |
| `scene list\|activate ID` | Scenes |
| `script list\|run ID` | Scripts |
| `config check\|reload` | Validate / reload core config without restart |
| `restart --yes` | Restart HA core (guarded) |

See `references/api.md` for REST endpoint mapping and the smoke-check verification steps.
