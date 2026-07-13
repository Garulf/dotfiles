---
name: character-sheets
description: Use when creating a character sheet, reference sheet, turnaround, or model sheet for an original character from a text description or from an existing image — including when krea2-character-images needs a sheet that doesn't exist in the server inputs yet.
---

# Character Sheets

## Overview

A full production character sheet is **two generated images**, not one:

1. **Turnaround sheet** — full-body views (front, ¾, side, back) in a neutral A-pose on white.
2. **Detail sheet** — large face close-up, five-expression row, color palette swatches, prop/detail callouts.

Never combine them into one all-in-one image: verified failure — asymmetric details get mirrored onto both sides (a mechanical LEFT arm becomes two mechanical arms) and panel layout degrades. Two dedicated images each came out correct on the same prompts.

Server mechanics (comfy.py, submit, upload): **REQUIRED BACKGROUND:** the `comfyui` skill. Palette and lighting adjectives for the prompts below: the `visual-craft` skill (light-and-color, anime-styles references). Use comfy.py's default server URL; the port has flipped between instances before (an old Desktop install answered on :8000), so if `stats` times out, probe the other port before concluding the machine is off.

## Step 1 — Canonical description

Distill the character into one prose block before generating: hair, eyes, skin, outfit piece by piece, signature props/companion, and any **asymmetric detail spelled out for BOTH sides** ("her LEFT arm is a mechanical bronze prosthetic with visible joints; her right arm is a normal human arm"). From an image, describe what you see in the same format. If the user left parts unstated (usually the lower body), invent plausible items, add them to the block, and tell the user — the sheet becomes canon, so the invention must be recorded, not silent. Save this block — it is also exactly what `krea2-character-images` needs for downstream scene prompts.

## Step 2 — Pick the path

| Input | Path |
| --- | --- |
| Text description only | **A: turbo txt2img** (both sheets) |
| Existing image of the character | **B: Identity Edit** (both sheets, pixel-faithful identity) |

## Path A — turbo txt2img (verified)

Standard Krea2 turbo graph: `UNETLoader krea2_turbo_fp8_scaled` (weight_dtype `default`) → `CLIPLoader qwen3vl_4b_fp8_scaled` type `krea2`; KSampler **8 steps / cfg 1 / euler / simple**, negative = `ConditioningZeroOut` of positive, VAE `qwen_image_vae`, `EmptySD3LatentImage` **1424×800, batch_size 2** (dims must be ÷16; batch 2 gives a pick-best pair per ~90 s job).

**Sheet 1 prompt template:**
> Anime style character design reference sheet, professional model sheet layout on a clean white background, flat studio lighting. Four full-body views of the SAME character standing in a neutral A-pose, arranged left to right in one row: front view, three-quarter view, side profile view, back view. Identical costume, proportions, and colors in every panel. The character: `<canonical description>`. `<companion>` sits at `<pronoun>` feet beside the front view only. Clean concept-art linework, consistent character design, turnaround sheet, highly detailed, masterpiece.

**Sheet 2 prompt template:**
> Anime style character design detail sheet, professional model sheet layout on a clean white background, flat studio lighting. The character: `<short description — hair, eyes, skin, upper-body outfit>`. Layout: on the left, one large face close-up portrait with a calm neutral expression. Along the top right, a row of five smaller face studies of the SAME face, each with a strongly different, exaggerated facial expression: first laughing joyfully with a wide open smile and closed happy eyes; second furious and shouting with deeply furrowed brows and bared teeth; third heartbroken and crying with tears; fourth shocked with huge wide eyes and open mouth; fifth smug with half-lidded eyes and a sly grin. The expressions must all look clearly different from each other. Bottom right, a color palette of paint swatches showing `<pronoun>` exact colors: `<named colors>`. Beside the swatches, detail callout drawings of `<props/asymmetric details/companion>`. Identical face and character design in every study, clean concept-art linework, character reference sheet, highly detailed, masterpiece.

**Raw variant (tested):** turbo is the default — 3–5× faster and passes the same checks. When a mid-size detail (tattoo, marking) keeps dropping, or the flat turbo look isn't wanted, swap `krea2_raw_fp8_scaled` + `ModelSamplingAuraFlow` shift 3.1 between UNETLoader and KSampler (without it raw txt2img is a mottled, washed-out mess), **50 steps / cfg 4**, and a real negative prompt becomes usable. Verified: raw held a scalp tattoo in every study where turbo was hit-and-miss. Caveats: raw renders prompt emphasis as literal sheet text (an all-caps "CRITICAL FACIAL DETAIL:" became a printed title) — keep phrasing descriptive, never caption-like; and raw does NOT fix tiny asymmetric eye features (blind eye failed 4/4 on raw after 8/8 on turbo — model-level limitation in both).

Two rules learned the hard way:

- **Describe each expression concretely** (mouth, brows, eyes). Naming them ("neutral, happy, angry, sad, surprised") collapses to five near-identical neutral faces. Adapt the set to the face — the templates use masculine/feminine placeholders, swap pronouns freely; on heavily bearded or stoic designs, "crying with tears" tends to render as merely sad, so substitute an expression that reads on that face.
- **Do not request text labels** — rendered text comes out as gibberish ("supfrade", "Silyor-White"). Omit labels entirely; palette swatches work fine unlabeled when the colors are named in the prompt.

## Path B — Identity Edit from an image (verified)

Graph (full node details: `krea2-character-images` skill, Identity Edit section): `LoadImage(uploaded source)` → `ImageScale 1024×1024` → `VAEEncode(qwen_image_vae)` → `Krea2EditModelPatch.source_latent`; `UNETLoader krea2_raw_fp8_scaled` → `LoraLoaderModelOnly krea2_identity_edit_v1_1_r128 @1.0` → patch `model`; two `Krea2EditGroundedEncode` (clip qwen3vl type `krea2`, `image` = scaled source, `grounding_px` 768, text input is **`prompt`**) for positive / empty negative; `EmptySD3LatentImage` 1424×800; KSampler **40 steps / cfg 3 / euler / simple / denoise 1**. ~2.5 min/job.

Prompt = the Path A templates reworded as an edit instruction, prefixed with:
> Turn this into a professional anime character design `<reference|detail>` sheet of this exact character, preserving his identity, face, hair, and outfit precisely.

and always append:
> Remove the `<original>` background entirely. The sheet fills the entire frame edge to edge on a plain white background.

A single natural posed image works as source; identity (hair, outfit, props) carries over pixel-faithfully including the full-body panels.

### Per-expression escalation (verified)

When the expression row keeps failing, or maximum expression quality is wanted: generate each expression as its own 1024×1024 Identity Edit portrait ("A close-up head and shoulders portrait of this exact character, preserving her identity… Her expression: `<concrete description>`… plain white background, exactly one face in the frame"), then composite into a strip with Pillow (`uv run --with pillow`). Verified: identity holds across separate generations; each failed panel retries alone (~2.5 min) instead of re-rolling the whole sheet. Costs ~5× the one-shot sheet and framing/zoom varies between panels even with identical framing language — normalize by cropping faces to matched scale when compositing, don't fight it in the prompt. Caveat: stubborn expressions stay stubborn solo (crying rendered weaker tears solo than the in-sheet first-position trick), so try the first-position fix before escalating.

## Inspect and re-roll (REQUIRED — never deliver unviewed sheets)

View every candidate at full size and check against the canonical description (or source image), then re-roll failures with a new seed + the fix, `_v2` prefix. Stop after 2 failed re-rolls and show the user the best attempt with the defect named.

| Defect | Look for | Fix on re-roll |
| --- | --- | --- |
| Mirrored asymmetry | LEFT-side detail appearing on both/wrong sides — check EVERY panel | Spell out both sides ("LEFT arm mechanical; right arm normal human"); if it persists, it usually means the all-in-one layout was used — split the sheets |
| Dropped small asymmetric feature | Heterochromia, small scars, or eye details rendered symmetric/normal in ALL candidates | Known turbo limitation at cfg 1 — spelling out both sides fixes large features (arms) but often not eye-level ones. After 2 failed re-rolls, deliver with the defect named and offer a follow-up edit of the eye region (img2img crop or Identity Edit) rather than more seeds |
| Identical expressions | Expression row is five neutral faces | Replace label names with concrete face descriptions (see rule above) |
| One expression won't render | A single expression (often crying) keeps coming out wrong across seeds | Move that expression to the FIRST position in the list — verified fix after description-strengthening alone failed |
| Gibberish text | Garbled labels anywhere | Remove all label/text requests from the prompt |
| Panel count drift | 4 views requested, 3 or 5 rendered | Benign if views are distinct and consistent — accept; only re-roll if a required view (front/side/back) is missing |
| Cross-panel inconsistency | Outfit pieces, colors, or proportions differ between views | Enrich the canonical description with the drifting detail; new seed |
| Sheet leakage (Path B) | Source background, extra scene elements | Append the remove-background / edge-to-edge clause |
| Bad hands/faces | Fused fingers, melted small faces | New seed; faces in detail-sheet studies are large enough that this is rare |

## Step 3 — Deliver

1. Show the user both sheets and get approval (offer re-rolls of anything they dislike).
2. On approval: `comfy.py upload <sheet>.png` to the server inputs folder (this is where `krea2-character-images` expects sheets) and keep local copies; tell the user both locations.
3. Optional phone delivery: scp into the **live instance's** `output\` directory on albedo and share `<server>/view?filename=<name>&type=output`. albedo has multiple ComfyUI installs and the old Desktop path (`Documents\ComfyUI`) is stale — find the running instance's base directory first (procedure in the comfyui skill's api.md, "Find the live base directory").

## Common mistakes

| Mistake | Result / fix |
| --- | --- |
| One all-in-one sheet with everything | Asymmetric details mirrored, cramped panels → two dedicated sheets |
| Expression row by label names | Five neutral faces → concrete per-expression descriptions |
| Requesting text labels | Gibberish text → no labels; name colors in the prompt instead |
| Insisting on exact panel counts | The model adds/drops a view; fine if all required views are present |
| `EmptyLatentImage` or non-÷16 dims | Node error / wrong latent type → `EmptySD3LatentImage`, dims ÷16 |
| Trusting a remembered port after a timeout | The port has flipped between instances (:8188 current, :8000 old Desktop) → probe both before declaring the server down |
| Delivering unviewed sheets | Defects ship → inspect every panel of every candidate |
