#!/usr/bin/env python3
"""Normalize YouTube caption files into a flat, timestamped transcript.

Reads a json3 (preferred) or vtt caption file and emits transcript.json:

    [{"start": <sec>, "end": <sec>, "text": "..."}, ...]

json3 auto-captions arrive as rolling windows where each event repeats the tail
of the previous one; this collapses them into clean, non-duplicated cues.

Usage:
    normalize_transcript.py <subs_file> [-o transcript.json]
    normalize_transcript.py --workdir <dir>   # auto-pick best subs.* file
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys


def _overlap_len(prev: str, nxt: str) -> int:
    """Length of the longest suffix of `prev` that is a prefix of `nxt`.

    A positive result is the rolling-caption signature: the next window repeats
    the tail of the previous one. Zero means the two cues are distinct content.
    """
    if not prev or not nxt:
        return 0
    for k in range(min(len(prev), len(nxt)), 0, -1):
        if prev.endswith(nxt[:k]):
            return k
    return 0


def parse_json3(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    cues: list[dict] = []
    for ev in data.get("events", []):
        segs = ev.get("segs")
        if not segs or "tStartMs" not in ev:
            continue
        text = "".join(s.get("utf8", "") for s in segs)
        text = text.replace("\n", " ").strip()
        if not text:
            continue
        start = ev["tStartMs"] / 1000.0
        dur = ev.get("dDurationMs", 0) / 1000.0
        cues.append({"start": start, "end": start + dur, "text": text})
    return cues


_TS = re.compile(r"(\d{2}):(\d{2}):(\d{2})[.,](\d{3})")


def _ts(m: re.Match) -> float:
    h, mnt, s, ms = (int(g) for g in m.groups())
    return h * 3600 + mnt * 60 + s + ms / 1000.0


def parse_vtt(path: str) -> list[dict]:
    cues: list[dict] = []
    with open(path, encoding="utf-8") as fh:
        block: list[str] = []
        start = end = None
        for line in fh:
            line = line.rstrip("\n")
            if "-->" in line:
                ts = _TS.findall(line)
                if len(ts) >= 2:
                    start = _ts(_TS.search(line))
                    end = _ts(list(_TS.finditer(line))[1])
                block = []
            elif line.strip() == "":
                if start is not None and block:
                    text = " ".join(block)
                    # strip inline vtt tags like <00:00:01.000><c> word</c>
                    text = re.sub(r"<[^>]+>", "", text).strip()
                    if text:
                        cues.append({"start": start, "end": end, "text": text})
                start = end = None
                block = []
            elif line.strip().upper() in ("WEBVTT",) or line.startswith(("Kind:", "Language:", "NOTE")):
                continue
            else:
                block.append(line.strip())
    return cues


def collapse(cues: list[dict]) -> list[dict]:
    """Fold rolling auto-caption windows together while keeping distinct cues.

    Only merges when the next cue textually overlaps the tail of the previous
    one (the rolling-window signature) — adjacent-but-distinct sentences stay
    separate so beat boundaries can snap to real cue edges.
    """
    out: list[dict] = []
    for c in cues:
        prev = out[-1] if out else None
        k = _overlap_len(prev["text"], c["text"]) if prev else 0
        contiguous = prev and c["start"] <= prev["end"] + 0.05
        if prev and contiguous and (k > 0 or c["text"] == prev["text"]):
            prev["text"] = prev["text"] + c["text"][k:]
            prev["end"] = max(prev["end"], c["end"])
        else:
            out.append(dict(c))
    return out


def pick_subs(workdir: str, lang: str = "en") -> str | None:
    """Pick the best caption file, preferring the exact language.

    yt-dlp may leave several tracks (subs.en.json3, subs.en-orig.json3, and
    auto-translations like subs.en-ar.json3). Rank so the genuine source-language
    track always beats a translation, and json3 beats vtt.
    """
    def rank(path: str) -> tuple:
        name = os.path.basename(path)
        code = name[len("subs."):].rsplit(".", 1)[0]  # e.g. "en", "en-orig", "en-ar"
        fmt = 0 if path.endswith("json3") else 1
        if code in (f"{lang}-orig", lang):
            tier = 0                      # original / exact language
        elif code.startswith(f"{lang}-US") or code.startswith(f"{lang}-GB"):
            tier = 1                      # common English regions
        elif code == lang or code.startswith(f"{lang}."):
            tier = 2
        else:
            tier = 3                      # anything else (likely a translation)
        return (tier, fmt, name)

    cands = glob.glob(os.path.join(workdir, "subs.*json3")) + \
        glob.glob(os.path.join(workdir, "subs.*vtt"))
    if not cands:
        return None
    return sorted(cands, key=rank)[0]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("subs_file", nargs="?")
    ap.add_argument("--workdir")
    ap.add_argument("--lang", default="en", help="preferred caption language (default en)")
    ap.add_argument("-o", "--out")
    args = ap.parse_args()

    path = args.subs_file
    if not path and args.workdir:
        path = pick_subs(args.workdir, args.lang)
    if not path:
        sys.exit("no caption file given or found (subs.*json3 / subs.*vtt)")

    if path.endswith("json3") or path.endswith(".json"):
        cues = parse_json3(path)
    else:
        cues = parse_vtt(path)
    cues = collapse(cues)

    out = args.out or os.path.join(os.path.dirname(path) or ".", "transcript.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(cues, fh, ensure_ascii=False, indent=1)
    dur = cues[-1]["end"] if cues else 0
    print(json.dumps({"transcript": out, "cues": len(cues),
                      "duration_sec": round(dur, 1)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
