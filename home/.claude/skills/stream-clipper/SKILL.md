---
name: stream-clipper
description: Use when turning a long YouTube livestream VOD into one condensed, narrative-focused video — cutting an hours-long stream down to a single ≥10-minute story stitched from its best moments. Not for live/in-progress capture, vertical reframing, or burned-in captions.
---

# Stream Clipper

Turns a finished, hours-long YouTube livestream into **one condensed video** — a single
cut, **≥10 minutes**, stitched from moments spread across the stream so they tell **one
coherent story**. The scripts do the mechanical work (download, transcribe, cut, stitch);
**you do the narrative judgment** — reading the whole transcript and choosing which
moments become the video and in what order. That judgment is the reason this is a skill.

**Output is exactly one video per stream**, in the source's original aspect ratio, hard
cuts by default. Fully automated: no approval gate — but you are the first and only
reviewer, so the self-review below is not optional.

## When to use / when NOT to use

**Use** to condense a long VOD into a single narrative short(ish) video.

**Do NOT use** for: capturing a stream that's still live (this needs the finished VOD),
multiple separate clips per stream, vertical 9:16 reframing, or burned-in captions —
all out of scope. For raw one-shot trimming with no story-building, just use `ffmpeg`
directly; this skill's transcript-driven selection is overhead you don't need.

## Pipeline

Work in one `workdir` per stream (e.g. `/tmp/clip_<id>/`). Full recipes, flags, and
gotchas are in `references/pipeline.md`; the selection craft is in
`references/narrative-selection.md`. Create a todo per step.

1. **Tooling check / install.** Ensure `yt-dlp`, `ffmpeg`, `ffprobe` are on PATH; install
   any missing per `references/pipeline.md` (`uv tool install yt-dlp`;
   `apt-get install -y ffmpeg` or `uv pip install static-ffmpeg`). Install `faster-whisper`
   only if step 3 needs the fallback.

2. **Fetch** — `python scripts/fetch.py "<url>" <workdir>`. Downloads the mp4, English
   captions (creator + auto), and `info.json` (with YouTube **chapters**). Check the
   printed `have_captions` flag.

3. **Transcript** → `transcript.json` = `[{start, end, text}]`:
   - Captions present → `python scripts/normalize_transcript.py --workdir <workdir>`.
   - No captions → `python scripts/transcribe.py <workdir>/video.mp4 -o <workdir>/transcript.json --model base`.

4. **Select + sequence the beats (your job).** Read the **full** `transcript.json` (use
   the `chapters` in `info.json` as hints, not answers). Following
   `references/narrative-selection.md`: name a single **through-line**, pick the **beats**
   that serve it (snapped to sentence/caption boundaries), order them (chronological by
   default), and make them sum to **≥10 min**. Write `<workdir>/segments.json` in the
   documented schema — every beat needs a `rationale` that ties to the through-line.

5. **Build** — `python scripts/build.py <workdir>/segments.json <workdir>/video.mp4 <workdir>/out`.
   Cuts each beat, re-encodes, and concatenates into `out/final.mp4` (+ `manifest.json`,
   `README.md`). Add `--crossfade 1` for dissolves, `--min-seconds N` to change the floor.
   It **hard-fails** if the result is under the minimum or missing a stream.

6. **Report.** Give the user `out/final.mp4`, its title, total runtime, and the ordered
   beat list (source in→out + why each earns its place) from `out/README.md`.

## Self-review — you are the only reviewer

There is no approval gate, so nothing catches a weak cut except you. Before reporting:

- **Re-read your `segments.json` beat list top to bottom.** Does it read as *one story*
  with a hook, development, and a landing — or a disjointed montage? If montage, reselect.
- **Every beat serves the through-line.** A funny-but-irrelevant tangent gets cut; that
  discipline is what makes it a story and not a clip reel.
- **No beat starts or ends mid-sentence**; beats don't overlap.
- **The build passed its check** (`final.mp4` ≥ `--min-seconds`, has video+audio). If
  `build.py` exited non-zero, fix `segments.json` (usually: not enough real material to
  reach the floor — widen strong beats or add one; never pad with filler you'd cut).
- **Spot-check the result** — `ffprobe` the duration and, if unsure about a transition,
  extract a frame at a cut point to confirm it's clean.

## Red flags — STOP and fix

- Selecting beats without first naming the through-line in one sentence.
- Keeping a moment you can't write a through-line-tied `rationale` for.
- Beats that reference removed material ("as I was saying…") after cutting.
- Reordering beats so an outcome plays before its setup.
- Reporting `final.mp4` without reading `build.py`'s exit status / self-review output.
- Trying to hit `--min-seconds` by padding with dead air or filler instead of real beats.
- Reaching for this skill on a stream that hasn't ended (no full VOD/transcript yet).
