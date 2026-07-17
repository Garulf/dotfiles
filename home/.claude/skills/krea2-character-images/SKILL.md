---
name: krea2-character-images
description: Use when generating images or wallpapers of a specific recurring character with Krea2 on the ComfyUI server — when a character sheet exists in the inputs folder, when characters render stiff/frontal with wrong perspective or posing, when a sheet's grid layout or white background leaks into the output, or when the character appears duplicated in the frame.
---

# Krea2 Character Images

## Overview

Two workflows put a known character into a new scene; picking the wrong one is the main failure mode. **Default to turbo txt2img with the character described in prose** — it composes pose, perspective, and scene together naturally. Identity Edit copies the design pixel-exactly but inherits the character sheet's stiff frontal stance.

Server mechanics (comfy.py, submit, models): **REQUIRED BACKGROUND:** the `comfyui` skill. No character sheet in the inputs folder yet? Create one first with the `character-sheets` skill.

## Characters — read the profile first

Each recurring character's data lives in a **`character.md` profile in their sheet folder**, not in this skill. Server path: `input/<slug>/character.md`. The profile holds the canonical prose description, trigger word, LoRA + strength rules, sheet file list, lore, and verified notes.

**Before generating, read the character's `character.md`** and use the canonical description as the prose identity. To see who exists, list the character folders under the server input dir. If a character has no profile yet, create their sheet + profile first with the `character-sheets` skill.

Known characters (convenience index — the folders under the server input dir are the source of truth; add a row when you create a new one):

| Character | Profile (`input/<slug>/character.md`) | Trigger / LoRA | Sheet(s) in folder |
|---|---|---|---|
| Cyberpunk mercenary hacker | `input/cyberpunk-merc-hacker/character.md` | `nvcyra` / `cyberpunk-merc-hacker_rank32.safetensors` (@1.0; light-skin retrain, rifle+visor togglable) | `charsheet_light_turnaround.png`, `charsheet_light_detail.png` |
| White Mage sorceress | `input/white-mage-sorceress/character.md` | `qildra` / `whitemage_rank32.safetensors` (@1.0) | `wizard_sheet_00001_.png` |

Concepts for a character must fit the lore in their profile. New LoRAs are trained with the `character-lora-training` skill (full pipeline + driver script); its eval step writes the trigger/LoRA/strength back into the character's `character.md`.

**Training-set rule for new character LoRAs:** do NOT train only on white-background sheet crops — the LoRA learns the flat sheet style as part of the character and flattens every scene at full strength (verified with `nvcyra_v2`). Before training, generate 8–12 extra dataset images of the character in varied full scenes (streets, interiors, different lighting — the turbo prose recipe works) and mix them in with the sheet crops, captioned per the trait-free caption rule with scene/background words only ("standing in a rainy neon street at night"). A LoRA trained this way should hold identity at @1.0 without dragging the scene flat; verify with a scene render before registering it at @1.0.

**LoRA-in-scenes rule (verified strength sweep, 2026-07-14):** a LoRA trained on white-background sheet crops drags the WHOLE scene toward flat sheet style at @1.0 — outputs come out flat cel, sterile, low-detail. At @0.5 the scene is rich but identity vanishes. **Use @0.7 with the trigger word followed by the full prose description** (the prose holds identity where the weakened LoRA lets go) plus painterly language ("painterly, textured, atmospheric, full of depth, not flat"). @1.0 is fine only when a flat white background is wanted (portraits, new sheet views). **For style-transfer renders (oil painting, watercolor, any non-anime look): remove the LoRA entirely** — it pins the character to anime cel-shading at ANY strength (verified: at 0.5 the scene went painterly but she stayed crisp cel). Use prose-only identity; naming the target style's techniques (brushwork, palette, edges) steers better than a style label alone.

## Which workflow

| Need | Use |
| --- | --- |
| Character has a trained LoRA (the profile's `lora:`/`trigger:` fields are set) | **Turbo txt2img + `LoraLoaderModelOnly` @0.7 + trigger word + full prose description** — see LoRA-in-scenes rule below |
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

## Wallpaper pipeline

Default finished wallpaper: **turbo txt2img (+ LoRA) → 4x-UltraSharp → ImageScale lanczos 3840×2160 → save**. Builder: `scripts/wallpaper_pipeline.py` (`build(prompt, seed, prefix, lora=..., strength=..., trigger=..., face_detail=..., tile_detail=...)`, returns API JSON; `lora=None` for prose-only characters).

### Detail passes — OPT-IN, only when the user asks

FaceDetailer and the USDU tile pass are **not part of the default pipeline**. Add them only when the user requests them ("face detailer", "tile detailer", "detail pass", "USDU"). They add render time (~70 s → ~2.5 min per wallpaper) and re-diffuse pixels, so unrequested use risks unwanted changes.

**FaceDetailer** (`face_detail=True`) — re-samples just the face region at high res, fixing the soft/underdetailed eyes scaled-down faces suffer. Key settings (verified 2026-07-14): runs **AFTER the 4K upscale** on the full-res image (detailing the 864p base first then ESRGAN-upscaling just stretches a soft face — verified no gain), `guide_size 1024 / max_size 2048`, turbo sampler (8 steps / cfg 1 / euler / simple), **`denoise 0.4`** — enough to sharpen eyes/skin without changing face shape (0.5 sharpens more but softens the jaw). Detector = `UltralyticsDetectorProvider` with **`bbox/face_yolov8m.pt`**. Its positive prompt may keep the trigger word — it only touches the detected face bbox and can't duplicate the character.

**UltimateSDUpscale tile detail** (`tile_detail=True`) — re-diffuses every tile of the image for genuine texture detail. It REPLACES the plain ESRGAN 4K tail: USDU *is* the upscaler, `upscale_by 2.5` (1536×864 → 3840×2160) with `4x-UltraSharp.safetensors` as its `upscale_model`. Verified params (2026-07-15, 5/5 clean): `denoise 0.25`, turbo sampler (8 steps / cfg 1 / euler / simple), `tile_width/height 1024`, `mode_type Linear`, `mask_blur 8`, `tile_padding 32`, `seam_fix_mode None`, `tiled_decode true`. Two duplication guards, both mandatory:

- **Neutral, character-FREE positive prompt** (e.g. `highly detailed anime illustration, crisp line art, intricate textures, rich color, masterpiece quality`) via its own `CLIPTextEncode` — feeding the character/scene prompt grows mini-copies of the character in background tiles (verified A/B, nvcyra seed 663201: character prompt = 3 clones, neutral prompt = clean).
- **Base model WITHOUT the character LoRA** feeds USDU (`["1",0]`, not the LoRA node) — the LoRA model still drives base gen and FaceDetailer.

When both passes are requested, order is **USDU → FaceDetailer** (face pass runs on USDU's output).

Three ways the detailer silently no-ops (all verified 2026-07-14 — a no-op = output pixel-identical to input; confirm by diffing, or by saving FaceDetailer output slot 1 `cropped_refined` which is black when nothing was detected):

- **`face_yolov8s` doesn't detect this anime style** — log shows `640x640 (no detections)`. Use **`face_yolov8m`** (larger, detects the anime faces). Realistic-face YOLOs generally miss Krea2 anime faces.
- **Impact Subpack security whitelist** — `.pt` detectors are pickles; the subpack refuses to load any not listed in `<install>\ComfyUI\user\default\ComfyUI-Impact-Subpack\model-whitelist.txt` (log: "Loaded N model(s) from whitelist"). Add the base filename, one per line. The subpack reloads the file per-attempt, so **no restart** needed. Loading a non-whitelisted pickle stays blocked → detailer does nothing.
- **Model indexing** — Impact only scans the **install's own** `models/ultralytics/bbox`, not "extra" paths (F:). The `.pt` must physically live at `<install>\ComfyUI\models\ultralytics\bbox\`.

Installing a new detector: download from a trusted source (Bingsu/adetailer is the ADetailer standard), **verify SHA-256 against the HF LFS pointer** (`.../raw/main/<file>` returns `oid sha256:…`) before whitelisting.

**Lighting vs. face artifacts:** high-contrast colored rim-light / glowing particles washing directly across skin (e.g. a portal's energy) produce sparkly, broken highlights on the character regardless of the LoRA. Keep intense effects *around* the character, not across her face, when a pristine render matters.

## Identity Edit workflow

Graph: `LoadImage(crop)` → `ImageScale 1024×1024` → `VAEEncode(qwen_image_vae)` → `Krea2EditModelPatch.source_latent`; `UNETLoader(krea2_raw_fp8_scaled)` → `LoraLoaderModelOnly(krea2_identity_edit_v1_1_r128 @1.0)` → patch `model`; two `Krea2EditGroundedEncode` (clip=qwen3vl type `krea2`, `image`=the scaled crop, `grounding_px` 768) for positive/empty-negative; `EmptySD3LatentImage` → KSampler **40 steps / cfg 3 / euler / simple / denoise 1** → VAEDecode.

Rules learned the hard way:

- **Crop ONE clean full-body view from the sheet** and upload that. Feeding the whole multi-view sheet reproduces the sheet itself — grid of poses, detail callouts, white panels — regardless of instruction.
- Character sheets live in a character-named subfolder of the server inputs (e.g. the cyberpunk merc's are under `cyberpunk-merc-hacker/`) — reference them in `LoadImage` as `<character-folder>/<file>.png`; the path works in submitted workflows even if the combo listing doesn't show it.
- The text input on `Krea2EditGroundedEncode` is named **`prompt`** (not `text`).
- Append to every instruction: `Exactly one figure of her in the frame — no duplicates, no reference poses. The scene fills the entire frame edge to edge with no white borders, panels, or blank background.` Wide latents duplicate the subject, and white sheet background bleeds in otherwise (worst when the crop has lots of white).
- Wide 16:9 latents work fine for identity — no need to stay square.
- `image_b` / `source_latent_b` accept a second crop (front + back view) — untested.

## Inspect and re-roll (REQUIRED — never deliver unviewed images)

Generation is not done when the queue drains; it is done when every image has passed inspection. Spot-checking a sample misses defects — this workflow's failure rate is roughly 1 in 5 for character images.

0. Keep every file for a character (workflows, outputs, re-rolls) in ONE folder named after the character or a descriptive slug, and set every `SaveImage` `filename_prefix` to `<character-folder>/<image-name>` so the server's output directory matches — same convention as the `character-sheets` skill (its Workspace section has the details).
1. Download **every** output. For batches, build contact sheets (3-across, ~448px thumbs) and view them; view any suspect image at full preview size before judging it. **Sharpness cannot be judged at preview/thumbnail scale** — for every deliverable, also view a 100%-scale crop (face + one detail region) before sending; softness that's invisible scaled-down reads as "very blurry" to the user at full size (verified failure 2026-07-14).
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
| Blurry / soft output | Whole image lacks crisp line edges — check a 100%-scale crop, never the scaled preview | Identity edit: encode `source_latent` at the image's **native aspect** (a wide image squashed into 1024×1024 softens the output — verified 2026-07-14) and add the 4x-UltraSharp tail; txt2img: add the 4K tail |
| Prop defies the prompt across seeds | One object (e.g. rifle orientation) renders wrong in every roll — a model prior prompting can't beat | Stop re-rolling; feed the otherwise-good render through the Identity Edit graph with a keep-everything-change-only-X instruction, then re-upscale (verified: rotated a rifle muzzle-up after 4 failed prompt rolls) |

## Quick reference

| Setting | Value |
| --- | --- |
| Wallpaper latent | 1536×864 (txt2img) or 1424×800 (identity edit); `EmptySD3LatentImage` requires dims **÷16** — 1408×792 is invalid |
| 4K tail | VAEDecode → `4x-UltraSharp.safetensors` → `ImageScale` lanczos 3840×2160 |
| Face detail (opt-in) | AFTER the 4K tail: `FaceDetailer` (detector `bbox/face_yolov8m.pt`, denoise 0.4, guide 1024/max 2048) → save. Detector must be whitelisted in the subpack. Builder: `scripts/wallpaper_pipeline.py` `face_detail=True` |
| Tile detail (opt-in) | `UltimateSDUpscale` replaces the 4K tail: upscale_by 2.5 + 4x-UltraSharp, denoise 0.25, tile 1024², neutral character-free prompt, LoRA-free model. Builder `tile_detail=True` |
| Composition | "on the RIGHT/LEFT side/third of the frame" in plain language — qwen3vl follows it reliably |
| Timing (RTX 5080) | txt2img+4K ≈ 45 s; + face detail ≈ 70 s; + tile detail ≈ 2.5 min; identity edit ≈ 2.5 min |

## Common mistakes

| Mistake | Result / fix |
| --- | --- |
| Identity Edit for a posed scene | Character-sheet stance pasted into scene, broken perspective → use txt2img recipe |
| Full sheet as edit reference | Output IS a character sheet → crop one view |
| No anti-duplication clause at wide aspect | Twin characters, white panels → append the clause above |
| Vague pose text in txt2img | Stiff frontal standing pose → write concrete body mechanics + camera |
| Long trailing solo/anti-dup clause on Krea2 txt2img | **Base gen corrupts to rainbow NaN garbage** (verified across seeds; prompt-dependent, not a server fault). Anti-dup via appended clause does NOT work on Krea2 — negations backfire at cfg 1, short "solo" is inert, front "1girl, solo" forces a close-up. **Handle wide-aspect duplication by re-rolling the seed** (it's seed-dependent) and by describing the empty side as concise deserted environment. Keep prompts from ballooning — long ones are the corruption trigger |
| `EmptyLatentImage` or non-÷16 dims | Node error / wrong latent type → `EmptySD3LatentImage`, dims ÷16 |
| Delivering after spot-checking a sample | Defects ship (~1 in 5 fail rate) → inspect every image per the loop above |
| FaceDetailer / USDU added when the user didn't ask | Slower renders, re-diffused pixels the user didn't want → detail passes are opt-in; default tail is plain ESRGAN 4K |
| USDU fed the character prompt or the LoRA model | Mini-copies of the character grow in background tiles → neutral character-free prompt + LoRA-free base model |
