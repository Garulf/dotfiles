# Pipeline reference — tools, recipes, file formats

All scripts live in `scripts/` and are plain `python3` (stdlib only, except
`transcribe.py` which needs `faster-whisper`). Run them from anywhere; pass a
`workdir` that holds all intermediates for one stream.

## Tooling install (this container)

```bash
# yt-dlp
uv tool install yt-dlp            # or: uv tool upgrade yt-dlp

# JS runtime — recent yt-dlp needs one to extract some YouTube formats.
# Without it you'll see "No supported JavaScript runtime" and may get lower/
# missing video formats (captions/metadata still work). Install deno:
curl -fsSL https://deno.land/install.sh | sh    # then ensure deno is on PATH

# ffmpeg + ffprobe — prefer the system package
apt-get install -y ffmpeg         # needs root; usually available in the dev container
# fallback with no root:
uv pip install static-ffmpeg && python -m static_ffmpeg   # puts ffmpeg/ffprobe on PATH

# whisper fallback (only when a VOD has no captions)
uv pip install faster-whisper
```

Verify: `yt-dlp --version`, `ffmpeg -version`, `ffprobe -version`.

## File map for one run

```
<workdir>/
  info.json          # yt-dlp metadata incl. chapters, title, duration
  subs.<lang>.json3  # captions (json3 preferred) — or .vtt
  video.mp4          # merged best-quality source
  transcript.json    # [{start,end,text}] — from captions OR whisper
  segments.json      # YOU write this (see narrative-selection.md)
  out/
    final.mp4        # the one condensed video
    manifest.json    # machine-readable assembly record
    README.md        # human-readable beat table
```

## 1. fetch.py

```bash
python scripts/fetch.py "<youtube_url>" <workdir> [--sub-lang en] [--cookies cookies.txt] [--no-video]
```

- Downloads best `bv*+ba/b` merged to mp4, `--write-subs --write-auto-subs`
  (`json3/vtt/best`), and `--write-info-json`.
- Members-only / age-gated VODs: pass `--cookies` (a Netscape cookies.txt).
- Prints a JSON summary incl. `have_captions` and `chapters` count — branch on
  `have_captions` to decide whether the whisper fallback is needed.

## 2. transcript

**Captions present** (fast, no GPU):

```bash
python scripts/normalize_transcript.py --workdir <workdir>   # auto-picks best subs.*
# or: normalize_transcript.py <subs_file> -o <workdir>/transcript.json
```

Handles json3 rolling-caption dedup (auto-captions repeat the tail of each line)
and strips inline vtt tags. Emits `transcript.json`.

**No captions** (fallback):

```bash
python scripts/transcribe.py <workdir>/video.mp4 -o <workdir>/transcript.json --model base
```

CPU + int8. Use `tiny`/`base`/`small` for hours-long streams; `medium`/`large-v3`
are impractical on CPU. `--vad_filter` is on to skip silence. Same output schema
as the caption path, so downstream steps don't care which ran.

## 3. build.py

```bash
python scripts/build.py <workdir>/segments.json <workdir>/video.mp4 <workdir>/out \
       [--pad 0.4] [--crossfade 0] [--min-seconds 600] [--crf 20] [--preset veryfast]
```

- Cuts each beat with `-ss <start> -i <src> -t <dur>` and **re-encodes** to a uniform
  format (`libx264` + `aac`, `yuv420p`) so concatenation is reliable across cut points
  that don't land on keyframes.
- Hard cuts → `concat` demuxer with `-c copy` (fast). `--crossfade N` → `xfade` +
  `acrossfade` filter chain (re-encoded, slower).
- Writes `final.mp4`, `manifest.json`, `README.md`.
- **Hard-fails** if `final.mp4` is under `--min-seconds` or missing a stream — this is
  the self-review guard for an unattended run.

### ffmpeg notes / gotchas

- Re-encoding is intentional: stream-copying arbitrary sub-second cuts from a single
  source produces broken concatenation (mismatched keyframes / timestamps). For a
  handful of ~1-min beats the encode cost is modest; raise `--preset` to `veryfast`
  (default) or `ultrafast` to trade size for speed.
- Keep all beats from the **same source** so resolution / SAR / fps match — the concat
  demuxer requires it. (This pipeline always does.)
- `--crossfade` shortens total runtime by `crossfade × (beats − 1)`; account for it
  against `--min-seconds`.
- Frame counts: `ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 file`.

## Quick full run

```bash
W=/tmp/clip_$$; python scripts/fetch.py "$URL" "$W"
python scripts/normalize_transcript.py --workdir "$W"      # or transcribe.py fallback
# → read $W/transcript.json, write $W/segments.json (narrative-selection.md)
python scripts/build.py "$W/segments.json" "$W/video.mp4" "$W/out"
```
