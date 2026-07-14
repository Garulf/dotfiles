# Home Assistant REST API Reference

## API Endpoint Mapping

Each subcommand maps to the following REST endpoints:

- `ping` → `GET /api/` (connectivity check)
- `states` → `GET /api/states`, `GET /api/states/<entity_id>`
- `call` → `POST /api/services/<domain>/<service>`
- `services` → `GET /api/services`
- `history` → `GET /api/history/period/<timestamp>?filter_entity_id=<id>`
- `logbook` → `GET /api/logbook/<timestamp>`
- `template` → `POST /api/template`
- `config check` → `POST /api/config/core/check_config`
- `config reload` → `POST /api/services/homeassistant/reload_core_config`
- `automation reload` → `POST /api/services/automation/reload`
- `automation get`/`set` → `GET`/`POST /api/config/automation/config/<id>`
- `automation trigger` → `POST /api/services/automation/trigger`
- `scene activate` → `POST /api/services/scene/turn_on`
- `script run` → `POST /api/services/script/<object_id>` (or `script.turn_on`)
- `restart` → `POST /api/services/homeassistant/restart`

## Common Domains & Services Cheat Sheet

### Light (lighting control)
```
Domain: light
Common services:
  - light.turn_on    → fields: brightness_pct (0-100), rgb_color ([r,g,b])
  - light.turn_off
  - light.toggle
```

Example: `hass.py call light.turn_on --entity light.kitchen --data brightness_pct=75 rgb_color=[255,200,100]`

### Climate (temperature & HVAC)
```
Domain: climate
Common services:
  - climate.set_temperature → fields: temperature (°C or °F), hvac_mode
  - climate.set_hvac_mode
  - climate.turn_on
  - climate.turn_off
```

Example: `hass.py call climate.set_temperature --entity climate.living_room --data temperature=22`

### Media Player (audio, TV, etc.)
```
Domain: media_player
Common services:
  - media_player.play_media  → fields: media_content_type, media_content_id
  - media_player.turn_on
  - media_player.turn_off
  - media_player.media_play
  - media_player.media_pause
  - media_player.media_stop
  - media_player.volume_set   → fields: volume_level (0.0-1.0)
```

### Switch (binary on/off control)
```
Domain: switch
Common services:
  - switch.turn_on
  - switch.turn_off
  - switch.toggle
```

## Smoke Check (manual verification against the live server)

Run these steps against your Home Assistant instance to verify the skill is wired correctly:

1. `hass.py ping`                       → OK + version
2. `hass.py states --domain light`      → list of lights
3. `hass.py services --domain light`    → includes light.turn_on
4. `hass.py call light.turn_on  --entity <a_light>` → then
   `hass.py call light.turn_off --entity <a_light>` → state echoes on/off
5. `hass.py template '{{ states.light | list | count }}'` → a number

**Expected results:**
- Step 1: `ping` reports OK and a version string
- Step 2: Non-empty list of light entities
- Step 3: Service output includes `light.turn_on` and its fields
- Step 4: First call echoes `state: 'on'`, second call echoes `state: 'off'` (or vice versa)
- Step 5: Output is an integer count of all light entities

**Troubleshooting:**
- If `ping` is UNREACHABLE, the HA box is likely offline. Do not debug networking.
- If authentication fails (401), verify the token in `config.json` or `HA_TOKEN` env var.
- If an entity is not found (404), use `hass.py states --filter <keyword>` to discover the correct entity_id.
