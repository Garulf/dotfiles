# Narrative selection & sequencing

This is the part only the model can do. The scripts fetch, transcribe, and stitch;
**you** read the whole transcript and decide which moments become the one video.

## Goal

From an hours-long stream, assemble **one** condensed video, **≥10 minutes total**
(the `--min-seconds` default is 600), stitched from moments spread across the stream
that together tell **one coherent story**. Not a raw chapter. Not a disjointed
highlight montage. A story.

## The through-line first

Before selecting anything, read enough of the transcript to name the single
**through-line** — the spine the whole cut hangs on. One sentence. Examples:

- "One guild's doomed attempt at a world-first raid."
- "A tech demo that slowly goes off the rails."
- "The streamer talks themselves into buying the worst possible car."

Everything you keep must earn its place against that line. A genuinely funny tangent
that doesn't serve the through-line gets cut — that discipline is what separates a
story from a clip reel. If the stream has no spine at all, pick the strongest arc
present and say so in the title; don't force unrelated bits together.

## Selecting beats

A **beat** is one contiguous `{start, end}` slice. Choose beats that:

- **Advance the through-line** — setup, escalation, turn, payoff, resolution.
- **Stand on their own** enough to be intelligible after cutting — no dangling
  "as I was saying" that references removed material.
- **Have energy** — a decision, reaction, revelation, joke landing, conflict,
  or emotional beat. Drop dead air, "let me read chat," loading screens, long
  silences, repeated filler.

Aim for a shape: a **hook** early (something that makes you want to keep watching),
rising development in the middle, and a **payoff/landing** near the end. You usually
want several beats (roughly 4–12) rather than two long ones — variety sustains attention.

### Boundaries

- Snap `start`/`end` to **sentence / caption-cue boundaries** from `transcript.json`,
  never mid-word. Start a beat where a thought begins; end where one lands.
- Leave a breath: the build step adds `--pad` (default 0.4s) on each side, so aim a
  hair inside the natural pause and let padding cover the rest.
- Beats must not overlap. Keep them in the order you want them played.

### Ordering

Default to **chronological** — it preserves cause and effect and avoids continuity
whiplash (an outcome before its setup). Reorder only when it demonstrably improves
the story (e.g. a cold-open payoff you then rewind to explain). If you reorder, make
sure nothing references events the viewer hasn't seen yet.

### Hitting the length target

Sum your beat durations as you go.

- **Under `--min-seconds`:** widen the strongest beats to include more of their
  natural context, or add another qualifying beat. Do **not** pad with filler you'd
  otherwise cut — a 9-minute strong cut beats a 10-minute padded one, but the target
  is a floor, so find real material to reach it.
- **Well over:** keep the beats that best serve the through-line; drop the weakest.

## Using the chapter hints

`info.json` may contain YouTube **chapters** (`chapters: [{start_time, end_time, title}]`).
Treat them as **hints**, not answers — they mark topic boundaries the streamer flagged,
which is a useful prior for where arcs begin/end. The narrative judgment is still yours;
chapters won't tell you what's *good*.

## Output: segments.json

Write exactly this schema (consumed by `build.py`):

```json
{
  "title": "How the raid fell apart",
  "throughline": "one guild's doomed attempt at a world-first",
  "beats": [
    {
      "start": 812.0,
      "end": 1102.0,
      "label": "Pull 1 — confident briefing",
      "rationale": "establishes the goal and the cocky tone that pays off later"
    },
    {
      "start": 4380.5,
      "end": 4611.0,
      "label": "The wipe streak begins",
      "rationale": "first crack in the plan; escalates the stakes"
    },
    {
      "start": 9017.0,
      "end": 9330.0,
      "label": "Blaming the healer",
      "rationale": "the emotional turn — payoff of the earlier confidence"
    }
  ]
}
```

- `start`/`end` in **seconds** (floats), from `transcript.json` timings.
- `label`: short human tag (shows in the README table).
- `rationale`: one line on why this beat earns its place — this is also your own
  check. If you can't write a rationale that ties to the through-line, cut the beat.

## Self-check before handing off to build.py

- Beats sum to ≥ `--min-seconds` (build.py hard-fails otherwise).
- No overlaps; chronological unless you deliberately reordered.
- Every `rationale` references the through-line.
- No beat starts/ends mid-sentence.
- Read the `label`/`rationale` list top to bottom — does it read as one story?
