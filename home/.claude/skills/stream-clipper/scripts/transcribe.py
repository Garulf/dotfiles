#!/usr/bin/env python3
"""Fallback transcription with faster-whisper when a VOD has no captions.

Produces the exact same schema as normalize_transcript.py so the rest of the
pipeline doesn't care where the transcript came from:

    [{"start": <sec>, "end": <sec>, "text": "..."}, ...]

Runs on CPU with int8 quantization by default (no GPU in the dev container).
For hours-long streams prefer a small model; large models are impractical on CPU.

Usage:
    transcribe.py <audio_or_video> [-o transcript.json] [--model base] [--lang en]
"""
from __future__ import annotations

import argparse
import json
import os
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("media", help="video.mp4 or an audio file; ffmpeg extracts audio as needed")
    ap.add_argument("-o", "--out")
    ap.add_argument("--model", default="base",
                    help="faster-whisper model (tiny/base/small/medium/large-v3); default base")
    ap.add_argument("--lang", default=None, help="force a language code (default: autodetect)")
    ap.add_argument("--compute-type", default="int8")
    args = ap.parse_args()

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        sys.exit("faster-whisper not installed. Install with: uv pip install faster-whisper")

    model = WhisperModel(args.model, device="cpu", compute_type=args.compute_type)
    segments, info = model.transcribe(args.media, language=args.lang, vad_filter=True)

    cues = []
    for seg in segments:
        text = seg.text.strip()
        if text:
            cues.append({"start": round(seg.start, 3), "end": round(seg.end, 3), "text": text})
        # progress to stderr so long jobs show life
        print(f"\r  {seg.end:8.1f}s  {len(cues):5d} cues", end="", file=sys.stderr)
    print("", file=sys.stderr)

    out = args.out or os.path.join(os.path.dirname(args.media) or ".", "transcript.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(cues, fh, ensure_ascii=False, indent=1)
    print(json.dumps({"transcript": out, "cues": len(cues),
                      "language": info.language,
                      "duration_sec": round(cues[-1]["end"], 1) if cues else 0}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
