#!/usr/bin/env python3
"""Fetch a YouTube VOD plus its captions and metadata into a work directory.

Downloads the best mp4, English subtitles (creator + auto), and the info json
(which carries the video's chapters, title, and duration). Everything lands in
<workdir> with predictable names so the rest of the pipeline can find them.

Usage:
    fetch.py <url> <workdir> [--sub-lang en] [--cookies FILE] [--no-video]

Outputs in <workdir>:
    video.mp4        the merged best-quality video (unless --no-video)
    info.json        yt-dlp metadata (chapters, title, duration, ...)
    subs.<lang>.*    caption file(s): json3 preferred, vtt as backup
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), file=sys.stderr)
    subprocess.run(cmd, check=True)


def run_ok(cmd: list[str]) -> bool:
    """Best-effort run: warn on failure but don't abort the pipeline."""
    print("+", " ".join(cmd), file=sys.stderr)
    rc = subprocess.run(cmd).returncode
    if rc != 0:
        print(f"  (warning: exited {rc}; continuing)", file=sys.stderr)
    return rc == 0


def have(binary: str) -> bool:
    return shutil.which(binary) is not None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("url")
    ap.add_argument("workdir")
    ap.add_argument("--sub-lang", default="en",
                    help="subtitle language prefix (default: en, matches en, en-US, ...)")
    ap.add_argument("--cookies", help="cookies.txt for age/members-only VODs")
    ap.add_argument("--no-video", action="store_true",
                    help="skip the video download (captions/metadata only)")
    args = ap.parse_args()

    if not have("yt-dlp"):
        sys.exit("yt-dlp not found. Install with: uv tool install yt-dlp")

    os.makedirs(args.workdir, exist_ok=True)
    common = ["yt-dlp", "--no-playlist"]
    if args.cookies:
        common += ["--cookies", args.cookies]

    # 1) Metadata (chapters live here). Written regardless of --no-video.
    info_path = os.path.join(args.workdir, "info.json")
    run(common + ["--skip-download", "--write-info-json",
                  "-o", os.path.join(args.workdir, "info.%(ext)s"), args.url])
    # yt-dlp writes info.info.json for the -o template above; normalise the name.
    for cand in glob.glob(os.path.join(args.workdir, "info*.info.json")):
        if cand != info_path:
            shutil.move(cand, info_path)
            break

    # 2) Captions: creator subs first, auto-generated as fallback. json3 keeps
    #    word/segment timing; vtt is the readable backup.
    # `-orig` catches YouTube's original-language track; the bare code and
    # region variants (en-US/en-GB) cover the rest. Auto-translated tracks
    # (e.g. en-ar) may still be fetched — normalize_transcript.py prefers the
    # exact language so a translation never wins. Best-effort: a partial track
    # failure must not sink the whole fetch.
    sub_langs = f"{args.sub_lang}-orig,{args.sub_lang},{args.sub_lang}.*"
    run_ok(common + [
        "--skip-download", "--write-subs", "--write-auto-subs",
        "--sub-langs", sub_langs, "--sub-format", "json3/vtt/best",
        "-o", os.path.join(args.workdir, "subs.%(ext)s"), args.url,
    ])

    # 3) Video (best video+audio, merged to mp4).
    if not args.no_video:
        run(common + [
            "-f", "bv*+ba/b", "--merge-output-format", "mp4",
            "-o", os.path.join(args.workdir, "video.%(ext)s"), args.url,
        ])

    # Report what we got so the caller can branch on caption availability.
    subs = sorted(glob.glob(os.path.join(args.workdir, "subs.*")))
    chapters = []
    if os.path.exists(info_path):
        with open(info_path) as fh:
            info = json.load(fh)
        chapters = info.get("chapters") or []
    print(json.dumps({
        "workdir": args.workdir,
        "video": os.path.join(args.workdir, "video.mp4") if not args.no_video else None,
        "subs": subs,
        "have_captions": bool(subs),
        "chapters": len(chapters),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
