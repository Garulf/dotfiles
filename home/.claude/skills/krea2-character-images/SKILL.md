---
name: krea2-character-images
description: Use when generating images or wallpapers of a specific recurring character with Krea2 on the ComfyUI server — when a character sheet exists in the inputs folder, when characters render stiff/frontal with wrong perspective or posing, when a sheet's grid layout or white background leaks into the output, or when the character appears duplicated in the frame.
---

# Krea2 Character Images

## Overview

Two workflows put a known character into a new scene; picking the wrong one is the main failure mode. **Default to turbo txt2img with the character described in prose** — it composes pose, perspective, and scene together naturally. Identity Edit copies the design pixel-exactly but inherits the character sheet's stiff frontal stance.

Server mechanics (comfy.py, submit, models): **REQUIRED BACKGROUND:** the `comfyui` skill. No character sheet in the inputs folder yet? Create one first with the `character-sheets` skill.

## Which workflow

| Need | Use |
| --- | --- |
| Character posed naturally in a scene (wallpapers, action, camera angles) | **Turbo txt2img + prose description** (default) |
| Pixel-exact outfit/design fidelity, pose stiffness acceptable | Identity Edit (raw + LoRA) |
| Design fidelity AND natural pose | txt2img first; img2img over it with a sheet crop at denoise ~0.55 |

## Turbo txt2img recipe (default)

Standard turbo graph (8 steps / cfg 1 / euler / simple, `ConditioningZeroOut` negative, `EmptySD3LatentImage`). The work is in the prompt — four parts, in order:

1. **Header:** `Anime style, breathtaking cinematic wide desktop wallpaper, epic sense of scale and depth.`
2. **Character:** `On the RIGHT side of the frame, <prose description distilled from the sheet: hair, eyes, skin, outfit piece by piece, signature props/companion>` — the description IS the identity; be specific or fidelity drops.
3. **Pose + camera:** concrete body mechanics and viewpoint: `leans back against the wall, one boot propped, hands in pockets, seen from behind and the side, gazing away`. Vague poses ("standing in X") regress to the stiff frontal look.
4. **Scene:** `On the LEFT and center, <vista/environment>` then `rendered in rich three-dimensional detail with volumetric lighting wrapping their forms — full of depth, not flat. Cinematic lighting, highly detailed anime illustration, masterpiece`.

Vocabulary for parts 3–4 (camera angles, lighting, composition, style words): the `visual-craft` skill — especially its camera-and-lens and anime-styles references. The four-part structure above stays as-is; visual-craft supplies the words that go in it.

Expect ~90% identity fidelity (whatever the prose captures). Side-specific details (e.g. which arm is mechanical) may flip.

## Identity Edit workflow

Graph: `LoadImage(crop)` → `ImageScale 1024×1024` → `VAEEncode(qwen_image_vae)` → `Krea2EditModelPatch.source_latent`; `UNETLoader(krea2_raw_fp8_scaled)` → `LoraLoaderModelOnly(krea2_identity_edit_v1_1_r128 @1.0)` → patch `model`; two `Krea2EditGroundedEncode` (clip=qwen3vl type `krea2`, `image`=the scaled crop, `grounding_px` 768) for positive/empty-negative; `EmptySD3LatentImage` → KSampler **40 steps / cfg 3 / euler / simple / denoise 1** → VAEDecode.

Rules learned the hard way:

- **Crop ONE clean full-body view from the sheet** and upload that. Feeding the whole multi-view sheet reproduces the sheet itself — grid of poses, detail callouts, white panels — regardless of instruction.
- The text input on `Krea2EditGroundedEncode` is named **`prompt`** (not `text`).
- Append to every instruction: `Exactly one figure of her in the frame — no duplicates, no reference poses. The scene fills the entire frame edge to edge with no white borders, panels, or blank background.` Wide latents duplicate the subject, and white sheet background bleeds in otherwise (worst when the crop has lots of white).
- Wide 16:9 latents work fine for identity — no need to stay square.
- `image_b` / `source_latent_b` accept a second crop (front + back view) — untested.

## Inspect and re-roll (REQUIRED — never deliver unviewed images)

Generation is not done when the queue drains; it is done when every image has passed inspection. Spot-checking a sample misses defects — this workflow's failure rate is roughly 1 in 5 for character images.

1. Download **every** output. For batches, build contact sheets (3-across, ~448px thumbs) and view them; view any suspect image at full preview size before judging it.
2. Check each image against the defect table below. Compare character images against the **actual sheet**, not memory.
3. Re-roll each failure with a **new seed**, the fix from the table, and a `_v2` filename prefix (keeps the original for comparison).
4. Re-inspect re-rolls the same way. After 2 failed re-rolls of the same image, stop and show the user the best attempt with the defect named.

| Defect | Look for | Fix on re-roll |
| --- | --- | --- |
| Bad hands | Extra/fused/missing fingers, broken grip on props | New seed; if it persists, re-pose so hands are occupied or hidden ("hands in pockets", "gripping the reins") |
| Bad face | Melted or asymmetric features; worst on small/distant faces | New seed; or move camera closer / crop tighter so the face is larger in frame |
| Duplicated character | Second copy of the subject anywhere — check edges and mid-ground, not just the focal area | Append the anti-duplication clause (above); new seed |
| Sheet leakage | White panels/borders, grid layout, mini reference poses | Crop reference tighter; add "fills the entire frame edge to edge, no white borders or panels" |
| Off-model vs sheet | Wrong hair color/length, missing outfit pieces, swapped props, absent companion, mech arm on wrong side | txt2img: enrich the prose description with the missed detail; identity edit: use a cleaner/larger crop |
| Wrong style | Photoreal, flat cel-shade, chibi, or palette drift | Restate style header; add "not flat cel shading" / "not photorealistic" as applicable |
| Broken perspective/anatomy | Character floats above ground, limbs at impossible angles, scale mismatch with scene | Rewrite pose with concrete body mechanics and a stated camera angle; if using identity edit, switch to the txt2img recipe |
| Glitches | Upscaler artifacts, seams, smeared regions, half-rendered objects | New seed usually suffices; check the pre-upscale image if it persists |

## Quick reference

| Setting | Value |
| --- | --- |
| Wallpaper latent | 1536×864 (txt2img) or 1424×800 (identity edit); `EmptySD3LatentImage` requires dims **÷16** — 1408×792 is invalid |
| 4K tail | VAEDecode → `4x-UltraSharp.safetensors` → `ImageScale` lanczos 3840×2160 |
| Composition | "on the RIGHT/LEFT side/third of the frame" in plain language — qwen3vl follows it reliably |
| Timing (RTX 5080) | txt2img+4K ≈ 45 s; identity edit ≈ 2.5 min |

## Common mistakes

| Mistake | Result / fix |
| --- | --- |
| Identity Edit for a posed scene | Character-sheet stance pasted into scene, broken perspective → use txt2img recipe |
| Full sheet as edit reference | Output IS a character sheet → crop one view |
| No anti-duplication clause at wide aspect | Twin characters, white panels → append the clause above |
| Vague pose text in txt2img | Stiff frontal standing pose → write concrete body mechanics + camera |
| `EmptyLatentImage` or non-÷16 dims | Node error / wrong latent type → `EmptySD3LatentImage`, dims ÷16 |
| Delivering after spot-checking a sample | Defects ship (~1 in 5 fail rate) → inspect every image per the loop above |
