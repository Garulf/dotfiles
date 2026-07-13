# Project structure

Create one directory per production, named after the project (kebab-case), in the location the user prefers (ask; default `~/videos/<project>/`).

```
<project>/
  script.md            # treatment: premise, roster, shot list
  approvals.md         # gate log (append-only)
  concept/
    manifest.json      # per-item generation record (see below)
    style-sheet.png    # look-dev master: palette / lighting / render style
    char-<name>.png
    set-<name>.png
    prop-<name>.png
  storyboard/
    shot-01.png        # one keyframe per shot, zero-padded
    contact-sheet.png
  workflows/           # every submitted API-format workflow JSON, kept for reruns
  shots/
    shot-01.mp4        # (or .webp/.gif — whatever the video nodes emit)
  audio/
    music.flac / vo-01.wav
  final/
    <project>.mp4
```

## script.md format

```markdown
# <Title>

## Premise
2-5 sentences.

## Characters
- **<Name>** — appearance, wardrobe, personality relevant to visuals.

## Settings
- **<Name>** — location, time of day, mood, palette.

## Shot list
| # | Shot | Duration | Camera | Characters/Setting |
|---|------|----------|--------|--------------------|
| 01 | ... | 4s | slow push-in | Fox / Forest |
```

## concept/manifest.json format

One entry per approved item; this is the consistency contract for all downstream generation. Generate the **style sheet first** — every other item links back to it via `style_sheet` so the whole film shares one look. Use the same checkpoint + LoRA stack across all entries.

```json
{
  "style-sheet": {
    "file": "style-sheet.png",
    "type": "style-sheet",
    "prompt": "cinematic, moody teal-and-amber palette, soft rim light, 35mm film grain, painterly",
    "negative": "blurry, extra limbs, bad hands",
    "seed": 101010,
    "checkpoint": "<chosen base — e.g. flux-2-klein-base-9b-fp8>",
    "loras": ["<style-lora@0.6>"],
    "approved": "2026-07-11"
  },
  "char-fox": {
    "file": "char-fox.png",
    "type": "character-sheet",
    "views": ["front", "3q", "side", "back"],
    "style_sheet": "style-sheet",
    "prompt": "red fox, amber eyes, worn green scarf, character reference sheet, turnaround, ...",
    "negative": "blurry, extra limbs, bad hands, extra fingers",
    "seed": 424242,
    "checkpoint": "<same base as style sheet>",
    "loras": ["<same style-lora@0.6>"],
    "approved": "2026-07-11"
  }
}
```

The style sheet carries `"type": "style-sheet"`. Character sheets carry `"type": "character-sheet"` and a `views` list; single-reference items (props, settings, one-angle bit characters) omit `views`. Every non-style item links its master with `style_sheet`. Use one shared `checkpoint` + `loras` stack across the whole project so palette and render stay consistent.
Rejected/regenerated items overwrite their entry; only approved entries carry an `approved` date.

## approvals.md format

Append one block per gate decision:

```markdown
## 2026-07-11 — GATE 1 (script)
Scope: script.md rev 2
User: "approved, but keep shot 4 under 3 seconds"
Result: APPROVED (with noted constraint)
```

Feedback rounds that end in revision are logged too (`Result: REVISE`), so the history of direction survives context loss. After any context compaction or new session, re-read `approvals.md` and `manifest.json` before resuming — they are the source of truth for what is approved.
