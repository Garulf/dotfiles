# Production techniques

All generation uses the comfyui skill's helper:
`C="python3 ~/.claude/skills/comfyui/scripts/comfy.py"` — see that skill for workflow format and templates.

## Refresh on current best models (stage 1, do this first)

Open-source image/video models turn over **monthly** — a checkpoint that was state of the art last quarter is often superseded. Before locking choices, web-search the current landscape for *this kind* of video (e.g. "best open source image-to-video model ComfyUI <month year>", "best character-consistency image model ComfyUI", "LTX 2.3 Director latest workflow"). Note what's currently recommended, then match it against what's actually installed (`$C models`/`$C nodes`) — you can only use what's on the server, but you should know whether the installed option is still competitive or whether it's worth offering to download a newer one.

**Default:** for video, **LTX 2.3 + LTX Director** remains the pipeline's tested path (fast, low-VRAM, first/middle/last-frame keyframing, native single-pass audio). Switch away from it only when the web *and* the installed set give you something clearly, substantially better — not a marginal benchmark win. As of this writing the main alternatives are Wan 2.2 (most versatile, higher VRAM), HunyuanVideo, and CogVideoX (strongest text-following); confirm current standings at runtime rather than trusting this list.

## Capability discovery (stage 1)

```bash
$C stats                                  # reachability, VRAM
$C nodes --search ltx                     # LTX Director / LTXV nodes? (preferred video gen)
$C nodes --search wan                     # WanVideo* nodes?
$C nodes --search hunyuan ; $C nodes --search cogvideo
$C nodes --search svd ; $C nodes --search animatediff ; $C nodes --search vhs
$C nodes --search audio ; $C nodes --search ace ; $C nodes --search tts
$C models                                 # checkpoints / loras / vaes
$C models --type <FoundVideoLoaderNode>   # video model files
```

Record what you find at the top of `script.md` (a "## Capabilities" comment block) — shot durations, resolution, and audio plans must fit what's installed. VRAM matters: video models often need most of the card; plan clip length accordingly (start with 3–5s per shot).

## Choosing models for narrative (stage 1 → 3)

Pick from what `$C models` and `$C nodes` actually return — never assume a name is installed. Match each discovered option against what a multi-shot story needs, in priority order:

- **Character consistency** — an image model that responds to reference-image conditioning, plus a turnaround/identity helper. Look for a CharTurner-style or character-sheet LoRA (`$C models` filtered for "charturner"/"turnaround"/"character") and an IPAdapter / reference-image node family (`$C nodes --search ipadapter`, `--search reference`). This pairing is what carries a character across shots; prioritize it over raw base quality.
- **Cinematic style** — favor a base checkpoint with strong prompt adherence and a filmic look for framing/lighting/mood: an SDXL-class or Flux-family checkpoint usually beats older SD1.5 bases here. If several are installed, generate one test frame from each on the same prompt/seed and let the director pick at Gate 2.
- **Style-consistent art** — commit to **one** checkpoint (+ the same LoRA stack) for every concept item and keyframe so the whole film shares a palette and render. A style LoRA applied at a fixed weight across all shots locks this further. Switching base checkpoints mid-project breaks continuity — treat a change as a Gate 2 re-approval.
- **Motion / video** — prefer an **image-to-video** family so approved keyframes drive the clips. **LTX Director (the WhatDreamsCost node suite over ComfyUI-LTXVideo) is the preferred video generator** — favor it whenever installed (`$C nodes --search ltx`; look for `LTX Director`, `LTX Sequencer`, `LTX Keyframer`) for its speed, first/middle/last-frame keyframing, and timeline editing. If LTX is absent, fall back to WanVideo (I2V), else SVD (`img2vid`), else AnimateDiff. Fall back to text-to-video only when no i2v node exists. Confirm the model's native resolution/frame count with `$C models --type <node>` and set shot duration to fit.

Write the chosen checkpoint / LoRAs / video node into the `## Capabilities` block so downstream stages reuse them verbatim.

## Concept art / look development (stage 3)

- Start from the comfyui skill's `txt2img.json` template.
- **Style sheet first (look development).** Before any character or setting art, generate one — or a few — **style/look-dev frames** that establish the film's visual language: palette, lighting key, contrast, texture, and render style (e.g. `cinematic, moody teal-and-amber palette, soft rim light, 35mm film grain, painterly` for one film; `flat cel-shaded, bold outlines, high-key` for another). This is the master reference every other item and keyframe is generated to match — commit to **one** checkpoint + LoRA stack here and reuse it everywhere. Record it in `concept/manifest.json` as `type: "style-sheet"` and link every other item to it. A style LoRA at a fixed weight across all shots locks the look further. Switching the base checkpoint later breaks continuity — treat it as a Gate 2 re-approval.
- **Characters → character sheets** whenever the character recurs or is shown from more than one angle: one image holding a multi-view turnaround (front, 3/4, side, back) at consistent scale on a plain background; if the character emotes, generate the expression row as a **separate** detail sheet — combining turnaround and expressions into one image mirrors asymmetric details and degrades panel layout (verified; see the `character-sheets` skill for the two-sheet procedure). Prompt cues: `character reference sheet, model sheet, turnaround, multiple views of the same character, front view, side view, back view, neutral pose, plain white background, consistent design`. Check for a turnaround-oriented helper first (`$C nodes --search charturner`; `$C models` for a "charturner"/"character sheet" LoRA) — these hold identity far steadier than prompt alone.
  - **When a sheet is overkill**, use one full-body neutral reference instead: a bit character seen once from a single angle, or any prop. Settings: one wide establishing shot. The image is a reference, not a poster.
- Use a distinct fixed seed per item and record everything in `concept/manifest.json` immediately — for a sheet, note which views it contains.
- On rejection, change only what the feedback names (prompt wording, seed, checkpoint) and regenerate just that item.

## Storyboard (stage 4)

- One keyframe per shot at the final video's aspect ratio (match the video model's supported resolution).
- Build each keyframe prompt as: `<shot description> + <verbatim character prompt fragments from manifest> + <verbatim setting fragments>`, same checkpoint/LoRAs as the approved art. Keep each item's seed when the shot features one character; otherwise pick a new seed and iterate.
- If an IPAdapter / reference-image node family is installed (`$C nodes --search ipadapter`), feed the approved concept art in as a reference image — for a character sheet, crop the single view whose angle matches the shot before uploading. Much stronger consistency than prompt reuse alone. Upload references with `$C upload`.
- Contact sheet (frames must share dimensions):
  ```bash
  ffmpeg -i storyboard/shot-%02d.png -filter_complex "tile=4x3" storyboard/contact-sheet.png
  ```

## Shot clips (stage 5)

- Prefer **image-to-video** from the approved keyframe — LTX Director / LTXV first when installed (its keyframer takes the approved frame as first/last), else WanImageToVideo / SVD_img2vid: upload the keyframe (`$C upload`), reference it in a LoadImage node. The storyboard then *is* the first frame of each shot — maximal fidelity to what was approved.
- Discover the exact node graph the server supports: `$C nodes --search <family>` then `$C models --type <node>`; build the workflow from those, not from memory.
- Name outputs `shots/shot-NN.<ext>`; save every submitted workflow to `workflows/` so any shot can be re-rendered with tweaks.
- If a shot's output disappoints, regenerate that shot only (new seed or prompt tweak) — never touch approved keyframes without going back to Gate 3.

## Audio (stage 5)

- Music: look for ACE-Step / Stable Audio nodes (`$C nodes --search ace`, `--search stableaudio`). Text-conditioned; generate to the final cut's length.
- Narration: TTS node families vary (`--search tts`, `--search speech`). Generate per-line, place on the timeline by shot.
- Nothing installed → ask the user: silent, or do they supply a track?

## Assembly (ffmpeg)

`ffmpeg` may be absent in the dev container; use the verified fallback:
```bash
alias ffmpeg='uvx --from static-ffmpeg static_ffmpeg'
```

- **Normalize** clips first if codecs/sizes differ (also converts webp/gif clips):
  ```bash
  ffmpeg -i shots/shot-01.webp -c:v libx264 -pix_fmt yuv420p -r 24 norm/shot-01.mp4
  ```
- **Straight cut** (identical codecs):
  ```bash
  printf "file '%s'\n" "$PWD"/norm/shot-*.mp4 > list.txt
  ffmpeg -f concat -safe 0 -i list.txt -c copy final/cut.mp4
  ```
- **Crossfade** between two clips (repeat pairwise, or cut straight — crossfades are a style choice, ask the director):
  ```bash
  ffmpeg -i a.mp4 -i b.mp4 -filter_complex \
    "xfade=transition=fade:duration=0.5:offset=<lenA-0.5>" ab.mp4
  ```
- **Mux audio**:
  ```bash
  ffmpeg -i final/cut.mp4 -i audio/music.flac -c:v copy -c:a aac -shortest final/<project>.mp4
  ```
- Title card / credits: render a still (txt2img or plain drawtext), loop it:
  ```bash
  ffmpeg -loop 1 -t 3 -i title.png -c:v libx264 -pix_fmt yuv420p -r 24 norm/shot-00.mp4
  ```

Send the final file to the user and ask for final acceptance; log it in `approvals.md`.

**Never overwrite a delivered final.** Once `final/<project>.mp4` has been sent, a revision goes to a **new** file — `final/<project>-v2.mp4`, `final/<project>-sfx.mp4`, etc. — so an accepted cut is never clobbered by a work-in-progress render. Keep the silent cut (`final/<project>-silent.mp4`) and any music-only cut as separate files too; the audio mux reads the silent cut and writes a new scored file rather than editing in place. Intermediate `norm/` segments are disposable and may be overwritten freely.

## Self-review recipes (inspect before you send)

You must look at every artifact before the director does (see SKILL.md "Self-review" for the full defect checklist you run against each one). AI output routinely contains defects — inspect on the assumption there is one. Cheap ways to look:

- **Image:** Read the PNG directly.
- **Clip — motion sanity:** extract evenly spaced frames into one strip. Don't hardcode frame numbers — a clip may be shorter than you assume and a fixed `eq(n,64)` then selects nothing. Sample by fraction of the clip instead:
  ```bash
  # thumbnails across the whole clip regardless of length (start, then every ~0.5s)
  ffmpeg -i shots/shot-05.mp4 -vf "fps=2,scale=360:-1,tile=6x1" -frames:v 1 /tmp/s05.png
  ```
  Or, if you know the exact frame count `N` (`$C models --type <node>` / the workflow), pick first/mid/last explicitly with `eq(n\,0)+eq(n\,$((N/2)))+eq(n\,$((N-1)))`.
- **Whole cut — sequence/continuity:** one thumbnail every N seconds:
  ```bash
  ffmpeg -i final/cut.mp4 -vf "fps=1/2,scale=300:-1,tile=4x6" -frames:v 1 /tmp/strip.png
  ```
- **Audio present and not silent:** `ffmpeg -i final/x.mp4 -af volumedetect -f null -` → check `max_volume` isn't ~0 (silence) or clipping (0.0 dB everywhere).

Scrutinize every frame for: **hands/fingers** (count them — duplicated hand, six fingers, fused digits is the #1 failure), **anatomy** (extra/missing limbs, warped or asymmetric faces), **props** (arrow count, fletching at the nock not mid-shaft, a metal head not feathers at the tip), **artifacts/glitches** (smears, warping, garbled text, duplicated objects, background melt), **continuity** with the style sheet and character sheet, and — for clips — **temporal defects** (flicker, identity morphing between frames, popping/vanishing objects). Any of these → regenerate or surgical-fix (next section); never pass a known-broken frame as "close enough."

## Surgical fixes — img2img / instruction edit (don't always re-roll)

A localized flaw (an extra arrow, a wrong-colored prop, a stray limb) is usually faster and safer to fix with an **edit pass** that keeps the rest of the frame than with a fresh txt2img that changes the face/pose the director already approved.

- **Flux.2 Klein edit (reference-latent):** `VAEEncode` the source → feed the latent into `ReferenceLatent` on **both** the positive (instruction) and negative conditioning → sample an `EmptyFlux2LatentImage` at the source's native size via `CFGGuider`/`SamplerCustomAdvanced`. The instruction is a plain imperative ("remove the lower arrow so only one is nocked; keep everything else identical"). This is Kontext-style editing: it regenerates the whole frame but pins it to the reference, changing only what you name. Server template: `image_flux2_klein_image_edit_9b_base.json` (its graph is inside a UI **subgraph** — extract the subgraph's nodes/links to rebuild an API workflow).
- **Generic img2img fallback:** `VAEEncode` the source → `KSampler` at `denoise` 0.35–0.55 with the corrected prompt. Lower denoise preserves more; too low won't remove the flaw, too high drifts the face.
- **Iterate from the clean base, not the last edit** — chaining edits accumulates drift. When an edit makes it worse, revert to the last good version and retry from there with a new seed.
- Some props (a nocked arrow at a 3/4 angle) are genuinely hard for the model. After ~3 failed passes, offer the director a framing that sidesteps the problem (e.g. shoot the *follow-through* with an empty bow so there's no nocked arrow to render) rather than looping.

## Model tips (snapshot — verify against what's installed; look up current guidance)

**Snapshot as of 2026-07 — treat as a starting point, not gospel.** Model families move fast; the exact filenames, node names, and params below rot within a quarter or two. Always (1) web-search current best models/workflows for the task (see "Refresh on current best models" above), and (2) confirm node/param names against the live server (`comfy.py nodes/models`, `/object_info/<Node>`) before building anything.

- **Flux.2 Klein (txt2img):** UNET `flux-2-klein-base-9b-fp8` + `CLIPLoader type=flux2` (qwen_3_8b encoder) + VAE `full_encoder_small_decoder`; sampling via `Flux2Scheduler`→`SamplerCustomAdvanced` with `CFGGuider` (cfg ~5), `euler`, ~20 steps. Responds well to natural-language descriptions and to `character reference sheet, model sheet turnaround, front/side/back` cues for turnarounds. Native ~1 MP; keep width/height multiples of 16.
- **LTX Director (image-to-video) — the preferred video generator:** the [WhatDreamsCost-ComfyUI](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI) node suite (LTX Director 2.0) — a timeline editor for **LTX 2.3** over **ComfyUI-LTXVideo**. Requires `ComfyUI-LTXVideo` and `ComfyUI-KJNodes` installed and current (install the suite via ComfyUI-Manager or `git clone` into `custom_nodes/`; see the comfyui skill for adding nodes to the server). Key nodes: `LTX Director` (timeline: trim/split/combine, first/middle/last-frame prompts, retake mode, IC-LoRA, audio inpainting), `LTX Sequencer` (FFLF clips), `LTX Keyframer` (first/last-frame sequences), `Multi Image Loader`, `Load Video UI`, `Load Audio UI`, `Speech Length Calculator`. Feed the approved storyboard keyframe in as the first (or first/last) frame. It's fast and low-VRAM relative to the 14B WAN path and adheres well to camera/motion cues. Confirm exact node graph, native resolution, and frame count against the live server (`$C nodes --search ltx`, `/object_info/<Node>`) before building the workflow — LTX releases move quickly.

  **Basic usage** (the repo's own tutorials are still "coming soon," so start from an example workflow it ships and verify node names/params live):
  1. **Load a starting graph** — import one of the suite's example workflows (repo `examples/` or ComfyUI-Manager's template) rather than wiring `LTX Director` from scratch; it comes pre-connected to the ComfyUI-LTXVideo loader/sampler and VAE.
  2. **Build the timeline** — in the `LTX Director` node's timeline UI, add one segment per shot. Set each segment's **duration** (LTX clips are short; keep shots ~2–5 s) and let the segments sum to the shot's target length.
  3. **Assign keyframes** — drop the approved storyboard frame on a segment as its **first** frame (and the next shot's frame as the **last** frame for a first/last-frame transition, via `LTX Keyframer`/`LTX Sequencer`). Upload frames with `$C upload` or the suite's `Multi Image Loader`.
  4. **Prompt per segment (prompt relay)** — give each segment its own positive prompt built from the manifest fragments (`<shot action> + <verbatim character/setting fragments>`) plus a camera/motion cue; the prompt relay carries continuity between adjacent segments.
  5. **Audio (optional)** — LTX 2.3 can generate synced audio; add a track via `Load Audio UI`, and use `Speech Length Calculator` to size narration segments.
  6. **Generate, then retake** — queue the graph. If one segment is off, use **retake mode** to re-roll only that segment (new seed/prompt) instead of the whole timeline — the timeline equivalent of the skill's "regenerate that shot only" rule.
  7. **Export** — save the timeline (the node persists it) and take the rendered clips into the ffmpeg assembly step below. Self-review every segment (filmstrip recipe) before it reaches the director.
- **WAN 2.2 I2V 14B (image-to-video), the fast low-VRAM path:** two-stage high-noise + low-noise UNETs, each with its matching **LightX2V 4-step** LoRA at strength ~1.0, each through `ModelSamplingSD3` shift ~5.0. Two `KSamplerAdvanced` in series: high-noise adds noise over steps 0→2 (return_with_leftover_noise), low-noise continues 2→4; **cfg 1.0**, `euler`/`simple`, total 4 steps. VAE `wan_2.1_vae`, encoder `umt5_xxl`. On a ~16 GB card run ~832×480, 65 frames @16fps (~4 s); native supports up to 720p but that needs more VRAM. Bias motion with the positive prompt (camera move + subject action); the first frame is your approved keyframe.
- **ACE-Step (music):** all-in-one checkpoint via `CheckpointLoaderSimple`; `TextEncodeAceStepAudio` (tags = instruments/genre/mood/tempo, lyrics empty for instrumental) → `EmptyAceStepLatentAudio(seconds)` → `KSampler` (~50 steps, cfg ~5) → `VAEDecodeAudio` → `SaveAudio`. Generate to the final cut's length.
- **Stable Audio Open (SFX / ambient):** the repackaged checkpoint is **model-only** — `CheckpointLoaderSimple`'s CLIP output is None. Load the text encoder **separately**: `CLIPLoader(t5_base.safetensors, type=stable_audio)` (the ~800 MB Google T5-base weights, renamed). Then `CLIPTextEncode`→`ConditioningStableAudio(seconds_start=0, seconds_total=N)`→`EmptyLatentAudio`→`KSampler` (dpmpp_3m_sde_gpu/exponential, ~50 steps, cfg ~6)→`VAEDecodeAudio`. Prompt with concrete sound descriptions + a negative ("music, melody, voice"). **Output level is low and inconsistent** — always peak-normalize each clip before mixing (see below).
- **Missing audio models:** the server frequently ships with the audio *nodes* but no audio *checkpoints*. You can download them onto the server (ComfyUI-Manager if present, else place the file directly — see the comfyui skill). Common files: ACE-Step `ace_step_v1_3.5b.safetensors` → `checkpoints/`; Stable Audio `stable-audio-open-1.0.safetensors` → `checkpoints/` + `t5_base.safetensors` → `text_encoders/`.

## Editing the final cut (basic craft)

Beyond a straight concat, a watchable cut needs deliberate editing:

- **Pacing / shot length.** Hold establishing and emotional beats (~4 s); cut action and intercuts short (~1.5–2.5 s). Trim a clip with `-t <seconds>` (or `-ss <start> -t <dur>`) when you normalize it.
- **Intercutting.** For a two-subject exchange (a "last look"), render each subject as its own clip and alternate short segments rather than one long two-shot. A close-up of A then a close-up of B reads as a shared moment.
- **Normalize before concat.** Re-encode every clip to identical codec/size/fps/SAR so a stream-copy concat is seamless:
  ```bash
  ffmpeg -i shots/shot-01.mp4 -vf "scale=832:480:force_original_aspect_ratio=decrease,pad=832:480:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=16" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -an norm/01.mp4
  ```
- **Cuts vs. transitions.** Straight cuts are the default and usually best. Reach for a crossfade (`xfade`) or a fade to/from black only when it serves the story — and confirm with the director. Fade-in/out on the assembled cut:
  ```bash
  ffmpeg -i norm/cut.mp4 -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=<dur-1>:d=1.0" -c:v libx264 -pix_fmt yuv420p -crf 18 -an final/cut-faded.mp4
  ```
- **Layered audio mix (music bed + timed SFX).** Peak-normalize each SFX first (levels vary wildly), place one-shots at their shot's start time with `adelay`, set relative levels with `volume`, combine with `amix=normalize=0`, and catch peaks with `alimiter`. Shot start time = sum of preceding (possibly trimmed) clip durations.
  ```bash
  # normalize one SFX to -3 dB peak
  mx=$(ffmpeg -i sfx.flac -af volumedetect -f null - 2>&1 | grep -oE 'max_volume: -?[0-9.]+' | grep -oE '\-?[0-9.]+')
  ffmpeg -i sfx.flac -af "volume=$(python3 -c "print(-3-($mx))")dB" sfx-n.flac
  # mix: music bed + a whump placed at 32.7s, over the silent cut
  ffmpeg -i final/cut-faded.mp4 -i music.flac -i whump-n.flac -filter_complex \
    "[1:a]volume=0.85[m];[2:a]adelay=32700|32700,volume=0.95[w];[m][w]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]" \
    -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest final/<project>-sfx.mp4
  ```
- **Match audio length to picture** with `-shortest` and fade the music out with the picture (`afade=t=out:st=<dur-1>:d=1.2`).
