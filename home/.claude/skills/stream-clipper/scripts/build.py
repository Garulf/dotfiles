#!/usr/bin/env python3
"""Cut the selected beats from a VOD and stitch them into one final video.

Input segments.json (produced by the model — see references/narrative-selection.md):

    {
      "title": "How the raid fell apart",
      "throughline": "one guild's doomed attempt at a world-first",
      "beats": [
        {"start": 812.0, "end": 1102.0, "label": "...", "rationale": "..."},
        ...
      ]
    }

Each beat is cut (with padding), re-encoded to a common format, concatenated in
order, and written to <out>/final.mp4. A manifest.json and readable README.md
describe what was assembled. Fails loudly if the final runtime is under
--min-seconds so an automated run can't silently emit a too-short video.

Usage:
    build.py <segments.json> <video.mp4> <out_dir>
             [--pad 0.4] [--crossfade 0] [--min-seconds 600]
             [--crf 20] [--preset veryfast]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile


def run(cmd: list[str], quiet: bool = False) -> None:
    if not quiet:
        print("+", " ".join(str(c) for c in cmd), file=sys.stderr)
    subprocess.run(cmd, check=True,
                   stdout=subprocess.DEVNULL if quiet else None)


def ffprobe_duration(path: str) -> float:
    out = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", path,
    ]).decode().strip()
    return float(out)


def probe_streams(path: str) -> tuple[bool, bool]:
    out = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "stream=codec_type",
        "-of", "default=nw=1:nk=1", path,
    ]).decode().split()
    return ("video" in out, "audio" in out)


def fmt_ts(sec: float) -> str:
    h, rem = divmod(int(sec), 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def cut_beat(src: str, start: float, end: float, dst: str, crf: int, preset: str) -> None:
    """Re-encode one beat to a uniform format so concat/xfade is reliable."""
    dur = end - start
    run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-ss", f"{start:.3f}", "-i", src, "-t", f"{dur:.3f}",
        "-c:v", "libx264", "-crf", str(crf), "-preset", preset,
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
        "-avoid_negative_ts", "make_zero", "-movflags", "+faststart", dst,
    ], quiet=True)


def concat_hardcut(parts: list[str], out: str, workdir: str) -> None:
    listfile = os.path.join(workdir, "concat.txt")
    with open(listfile, "w") as fh:
        for p in parts:
            fh.write(f"file '{os.path.abspath(p)}'\n")
    run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
         "-f", "concat", "-safe", "0", "-i", listfile, "-c", "copy", out])


def concat_crossfade(parts: list[str], durs: list[float], out: str,
                     xf: float, crf: int, preset: str) -> None:
    """Chain beats with xfade (video) + acrossfade (audio)."""
    inputs: list[str] = []
    for p in parts:
        inputs += ["-i", p]
    vlab, alab = "[0:v]", "[0:a]"
    filt: list[str] = []
    offset = 0.0
    for i in range(1, len(parts)):
        offset += durs[i - 1] - xf
        vout = f"[v{i}]"
        aout = f"[a{i}]"
        filt.append(f"{vlab}[{i}:v]xfade=transition=fade:duration={xf}:offset={offset:.3f}{vout}")
        filt.append(f"{alab}[{i}:a]acrossfade=d={xf}{aout}")
        vlab, alab = vout, aout
    run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *inputs,
         "-filter_complex", ";".join(filt), "-map", vlab, "-map", alab,
         "-c:v", "libx264", "-crf", str(crf), "-preset", preset,
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
         "-movflags", "+faststart", out])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("segments")
    ap.add_argument("video")
    ap.add_argument("out_dir")
    ap.add_argument("--pad", type=float, default=0.4, help="pre/post padding per beat (sec)")
    ap.add_argument("--crossfade", type=float, default=0.0, help="dissolve between beats (sec)")
    ap.add_argument("--min-seconds", type=float, default=600.0)
    ap.add_argument("--crf", type=int, default=20)
    ap.add_argument("--preset", default="veryfast")
    args = ap.parse_args()

    for binary in ("ffmpeg", "ffprobe"):
        if not shutil.which(binary):
            sys.exit(f"{binary} not found. Install ffmpeg (apt-get install ffmpeg) "
                     f"or `uv pip install static-ffmpeg`.")

    with open(args.segments) as fh:
        spec = json.load(fh)
    beats = spec.get("beats") or []
    if not beats:
        sys.exit("segments.json has no beats")

    src_dur = ffprobe_duration(args.video)
    os.makedirs(args.out_dir, exist_ok=True)

    # Normalize + clamp beat boundaries with padding; keep chronological order
    # only if the model already ordered them — we honor the given order.
    norm = []
    for b in beats:
        start = max(0.0, float(b["start"]) - args.pad)
        end = min(src_dur, float(b["end"]) + args.pad)
        if end - start < 0.5:
            print(f"  skipping degenerate beat {b}", file=sys.stderr)
            continue
        norm.append({**b, "start": start, "end": end})
    if not norm:
        sys.exit("no usable beats after clamping")

    tmp = tempfile.mkdtemp(prefix="clip_", dir=args.out_dir)
    parts, durs = [], []
    for i, b in enumerate(norm):
        part = os.path.join(tmp, f"beat_{i:03d}.mp4")
        print(f"[{i+1}/{len(norm)}] cut {fmt_ts(b['start'])}-{fmt_ts(b['end'])}", file=sys.stderr)
        cut_beat(args.video, b["start"], b["end"], part, args.crf, args.preset)
        parts.append(part)
        durs.append(ffprobe_duration(part))

    final = os.path.join(args.out_dir, "final.mp4")
    if args.crossfade > 0 and len(parts) > 1:
        concat_crossfade(parts, durs, final, args.crossfade, args.crf, args.preset)
    else:
        concat_hardcut(parts, final, tmp)
    shutil.rmtree(tmp, ignore_errors=True)

    total = ffprobe_duration(final)
    has_v, has_a = probe_streams(final)

    manifest = {
        "title": spec.get("title", ""),
        "throughline": spec.get("throughline", ""),
        "source_video": os.path.abspath(args.video),
        "final": os.path.abspath(final),
        "total_seconds": round(total, 1),
        "crossfade": args.crossfade,
        "pad": args.pad,
        "beats": [
            {"index": i, "label": b.get("label", ""), "rationale": b.get("rationale", ""),
             "src_start": round(b["start"], 2), "src_end": round(b["end"], 2),
             "duration": round(b["end"] - b["start"], 2)}
            for i, b in enumerate(norm)
        ],
    }
    with open(os.path.join(args.out_dir, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)

    lines = [f"# {manifest['title'] or 'Condensed cut'}", "",
             f"**Through-line:** {manifest['throughline']}", "",
             f"**Runtime:** {fmt_ts(total)} ({round(total/60,1)} min) from "
             f"{len(norm)} beats · source `{os.path.basename(args.video)}`", "",
             "| # | Source in→out | Len | Beat | Why it's here |",
             "|---|---|---|---|---|"]
    for m in manifest["beats"]:
        lines.append(f"| {m['index']+1} | {fmt_ts(m['src_start'])}→{fmt_ts(m['src_end'])} "
                     f"| {int(m['duration'])}s | {m['label']} | {m['rationale']} |")
    with open(os.path.join(args.out_dir, "README.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print(json.dumps({"final": final, "total_seconds": round(total, 1),
                      "beats": len(norm), "has_video": has_v, "has_audio": has_a}, indent=2))

    # Self-review: fail loudly rather than emit a broken/short automated result.
    problems = []
    if not (has_v and has_a):
        problems.append("final is missing a video or audio stream")
    if total + 0.5 < args.min_seconds:
        problems.append(f"final runtime {total:.1f}s is under min-seconds {args.min_seconds:.0f}s")
    if problems:
        sys.exit("BUILD CHECK FAILED: " + "; ".join(problems))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
