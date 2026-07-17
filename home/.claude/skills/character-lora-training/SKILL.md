---
name: character-lora-training
description: Use when training a character LoRA for Krea2 on the albedo server — when a recurring character needs stronger identity than prose prompting gives, when a new character sheet exists and the user wants a LoRA, or when a previous character LoRA came out defective (identity not bound to trigger, or scenes render flat).
---

# Character LoRA Training

## Overview

Trains a rank-32 LoRA on **Krea-2-Raw** (bf16) with musubi-tuner on albedo, used at inference on **Krea2 Turbo** ("train on raw, infer on turbo" — verified). Pipeline: dataset from the character's sheets + scene renders → trait-free captions → cache → train ~4000 steps (≈3.5 h on the 16 GB 5080) → eval → register in the character's `character.md` profile.

Driver script: `scripts/train_lora.sh` (in this skill). Server/ssh background: the `comfyui` and `ssh-config` skills. Sheets come from the `character-sheets` skill.

## Step 1 — Dataset (this decides success or failure)

~20–35 images, 512px is enough, in `F:\musubi-tuner\dataset\<slug>\` with a same-name `.txt` caption per image:

1. **Crops from the character's two sheets** — each turnaround view and each expression study as its own image (white background).
2. **8–12 scene renders** — the character in varied full scenes/lighting (turbo prose recipe from `krea2-character-images`). NOT optional: a LoRA trained on white-background crops alone learns the flat sheet style as part of the character and flattens every scene at @1.0 (verified failure, `nvcyra_v2`).
3. **3–5 style-varied renders** — the character in a rendering style OTHER than the house anime look (e.g. painterly oils via the prose-only style-transfer recipe in `krea2-character-images`), each captioned with its style words (`nvcyra standing in an alley, painted in loose oil brushwork`). Same principle as the scene rule one level up: anything constant across the dataset gets baked into the trigger — `nvcyra_v2` was 100% cel-shaded and the LoRA pinned her to cel at ANY strength, blocking style-transfer renders. Captioned style variety makes rendering style promptable instead of baked.
4. Solo portraits/wallpapers of the character you already have.

**Caption rule (the v1-vs-v2 difference):** captions must be **trait-free**. Never caption immutable traits (hair color, skin, eye color, outfit) — identity binds to those words instead of the trigger and the bare trigger renders a generic person (v1's fatal flaw). Caption ONLY:

- the trigger token (an invented word, e.g. `nvcyra` — pick something with no prior meaning),
- view/pose/expression: `nvcyra, side profile view, neutral A-pose`,
- togglable extras: `wearing her visor helmet`,
- for scene images, scene/background words only: `nvcyra standing in a rainy neon street at night`.

## Step 2 — Stage, cache, train

```bash
scripts/train_lora.sh stage <slug> [steps]   # writes dataset TOML + train bat on albedo
# ... put dataset images + captions in F:\musubi-tuner\dataset\<slug>\ ...
scripts/train_lora.sh cache <slug>           # latents + text-encoder outputs (re-run after any dataset change)
scripts/train_lora.sh train <slug>           # launch — MUST run via Bash run_in_background
scripts/train_lora.sh status <slug>          # log tail + checkpoints
scripts/train_lora.sh fetch <slug>           # install final .safetensors into ComfyUI loras
```

Training params baked into the bat (all verified on the 16 GB card): rank/alpha 32, lr 1e-4 adamw8bit, bf16 + `--fp8_base --fp8_scaled`, `--blocks_to_swap 26`, `--timestep_sampling shift --discrete_flow_shift 2.5`, checkpoints every 500 steps plus `--save_state --save_last_n_steps_state 500` for exact resume. Expect ~3.2 s/step.

Hard-won rules the script encodes — don't undo them:

- **Free ComfyUI VRAM before the trainer initializes** (`train` does `POST /free`). A trainer that starts while ComfyUI holds VRAM is demoted to shared memory and stays ~2.4× slow even after VRAM frees — kill and relaunch, don't wait. Also check no second ComfyUI instance is live on the card.
- **`set PYTHONUTF8=1`** — cp1252 console crashes the trainer (and `hf download`) on Unicode.
- **Launch via persistent foreground ssh** (`train` execs it; run the Bash call with `run_in_background: true`). The remote process survives ssh-client death. `Start-Process` detach silently fails through ssh; `schtasks` is blocked by the auto-mode classifier.
- Lock screen costs nothing (verified full clocks) but **sleep freezes the run** — if the machine may sleep, tell the user.
- `--resume` restarts the step bar from 0 and trains `max_train_steps` MORE steps — plan the number accordingly.
- Don't run ComfyUI inference during training.

## Step 3 — Eval before registering

Test the 3000–4000-step checkpoints (`fetch <slug> <checkpoint file>`) on turbo with `LoraLoaderModelOnly`:

1. **Identity:** bare trigger word only, plain background portrait — must render the character, not a generic person (if generic → caption rule was violated; retrain).
2. **Scene:** trigger in a full scene prompt at @1.0 — the scene must stay rich, not collapse to flat sheet style (if flat → dataset lacked scene images).
3. **Minimal + togglables:** trigger + one togglable ("wearing her visor helmet").
4. **Style transfer:** trigger + a non-anime style prompt ("painted in loose oil brushwork") — the character must take the style, not snap back to cel (if she snaps back → dataset lacked captioned style variety).

Then register the winner in the character's **`character.md` profile** (in their sheet folder — server `input/<slug>/character.md`): set the `trigger:` and `lora:` fields and fill in the Trigger & LoRA section with the verified strength and any caveats (a well-mixed dataset should pass at @1.0; a sheet-only LoRA needs @0.7 + prose — see `krea2-character-images`' LoRA-in-scenes rule). The profile — not this skill or the image skill — is the registry; the `krea2-character-images` skill carries a convenience roster table of the known character profiles.

## Layout on albedo

| What | Where |
| --- | --- |
| musubi-tuner (uv env, torch cu128) | `F:\musubi-tuner\` |
| Train base + text encoder | `D:\musubi-models\raw.safetensors` (24.5 GB), `D:\musubi-models\text_encoders\qwen3vl_4b_bf16.safetensors` — big files on D:/E: (3 TB free), NOT F: |
| Dataset / configs / bats / logs / outputs | `F:\musubi-tuner\dataset\<slug>\`, `configs\<slug>_512.toml`, `train_<slug>.bat`, `train_<slug>.log`, `outputs\<slug>\` (pilot `nvcyra` predates the per-slug dataset dir; its images sit in `dataset\` root) |
| Installed LoRAs | `F:\Stable Diffusion\models\loras\` |

## Common mistakes

| Mistake | Result / fix |
| --- | --- |
| Captioning hair/eye/outfit traits | Identity binds to words, bare trigger = generic person (v1 failure) → trait-free captions, retrain |
| White-background crops only in dataset | LoRA flattens every scene at @1.0 (`nvcyra_v2` failure) → mix in 8–12 scene renders |
| Single rendering style across dataset | Style bakes into the trigger; LoRA blocks style-transfer at any strength (`nvcyra_v2`) → 3–5 style-varied renders, style named in captions |
| Trainer started while ComfyUI holds VRAM | Permanent ~2.4× slowdown → kill trainer, free VRAM, relaunch |
| `Start-Process` / `schtasks` to detach | Silent failure / permission block → persistent foreground ssh in a background Bash call |
| Missing `PYTHONUTF8=1` | cp1252 UnicodeEncodeError crash mid-run |
| Skipping re-cache after dataset edits | Trainer uses stale latents → re-run `cache` |
| Registering without the 3-part eval | Defective LoRA reaches the character's profile |
