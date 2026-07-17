#!/usr/bin/env python3
r"""Canonical Krea2 character wallpaper pipeline (API-format workflow builder).

Default: turbo txt2img (+ character LoRA) -> 4x-UltraSharp -> lanczos 3840x2160 -> save.

Detail passes are OPT-IN (only when the user asks for them):
  face_detail=True  -> FaceDetailer AFTER the 4K upscale, on the full-res image, so the face
                       is re-sampled at ~1024 for genuine detail. (Detailing the 864p base first,
                       then ESRGAN-upscaling, just stretches a soft face -- verified no gain
                       2026-07-14.) Gentle denoise 0.4 keeps the face shape; 0.5 sharpens more
                       but softens the jaw.
  tile_detail=True  -> UltimateSDUpscale REPLACES the plain ESRGAN tail: USDU is the upscaler
                       (upscale_by 2.5, 1536x864 -> 3840x2160, 4x-UltraSharp as upscale_model),
                       re-diffusing every tile at denoise 0.25 for real texture detail. Verified
                       2026-07-15 (5/5 clean). Duplication guards, both mandatory:
                         - neutral character-FREE tile prompt (character prompt grows mini-copies
                           of the character in background tiles -- verified A/B, nvcyra 663201)
                         - base model WITHOUT the character LoRA feeds USDU; the LoRA model
                           still drives base gen and FaceDetailer.
  Both on -> order is USDU -> FaceDetailer.

FaceDetailer detector: UltralyticsDetectorProvider with **bbox/face_yolov8m.pt**. Gotchas:
  1. face_yolov8s does NOT detect this Krea2 anime style at all ("no detections" in the log) --
     use the larger face_yolov8m (it detects the anime faces).
  2. Impact Subpack (V1.3.x) has a SECURITY WHITELIST for .pt detectors (they're pickles). A model
     not listed in
       <install>\ComfyUI\user\default\ComfyUI-Impact-Subpack\model-whitelist.txt
     loads NOTHING and the detailer becomes a silent no-op. Add the base filename (one per line).
     The subpack reloads the whitelist per-attempt, so no restart is needed.
  3. Impact only indexes the INSTALL's own models dir, so the .pt must physically live at
     <install>\ComfyUI\models\ultralytics\bbox\  (an "extra" path like F: is not scanned).
Both installed + whitelisted 2026-07-14 (face_yolov8m.pt sha256 717923c1...).

Usage:
  from wallpaper_pipeline import build
  wf = build(prompt, seed, prefix, lora="whitemage_rank32.safetensors", strength=1.0,
             face_detail=True, tile_detail=True)   # detail passes only when asked
  # ... json.dump(wf) then submit with comfy.py
For a LoRA-less character (prose-only), pass lora=None to drop the LoRA node.

CLI: build.py "<prompt>" <seed> <prefix> [lora] [strength] [trigger] [face] [tile]
     (trailing "face" / "tile" tokens enable the corresponding pass)
"""
import json, sys


# Wide (16:9) latents tend to duplicate the subject. Handling this is NOT a simple prompt append
# (verified 2026-07-14): a wordy solo/anti-dup clause CORRUPTS Krea2's base gen into rainbow NaN
# garbage; negation words ("no twin") backfire at cfg 1 and PRODUCE twinning; a trailing "Solo."
# does nothing; front-loaded "1girl, solo" tags force a close-up and still leave background dupes;
# narrowing the latent to 1216x832 still duplicates. Duplication is SEED-DEPENDENT -> the reliable
# fix is the inspect-and-re-roll loop (new seed), plus writing the empty side of the frame as an
# explicit environment ("On the LEFT, an empty stone balustrade and misty valley" — give the space
# a non-person subject so the model doesn't fill it with a second figure). No auto clause is applied.


TILE_PROMPT = ("highly detailed anime illustration, crisp line art, intricate textures, "
               "rich color, masterpiece quality")  # character-FREE on purpose (see docstring)


def build(prompt, seed, prefix,
          lora="whitemage_rank32.safetensors", strength=1.0,
          face_prompt="detailed face, clean smooth skin, sharp crisp features, detailed eyes",
          trigger="qildra", w=1536, h=864, face_denoise=0.4,
          face_detail=False, tile_detail=False, tile_denoise=0.25):
    model_ref = ["1b", 0] if lora else ["1", 0]
    wf = {
      # --- base generation ---
      "1":  {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_fp8_scaled.safetensors", "weight_dtype": "default"}},
      "2":  {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
      "3":  {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
      "4":  {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
      "5":  {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
      "6":  {"class_type": "EmptySD3LatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
      "7":  {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0, "model": model_ref, "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["6", 0]}},
      "8":  {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
      "13": {"class_type": "UpscaleModelLoader", "inputs": {"model_name": "4x-UltraSharp.safetensors"}},
    }
    if lora:
        wf["1b"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": lora, "strength_model": strength}}

    # --- 4K tail: plain ESRGAN by default; USDU tile-detail pass replaces it when asked ---
    if tile_detail:
        wf["17"] = {"class_type": "CLIPTextEncode", "inputs": {"text": TILE_PROMPT, "clip": ["2", 0]}}
        wf["18"] = {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["17", 0]}}
        wf["19"] = {"class_type": "UltimateSDUpscale", "inputs": {
            "image": ["8", 0], "model": ["1", 0],  # base model, no LoRA: keeps her out of bg tiles
            "positive": ["17", 0], "negative": ["18", 0], "vae": ["3", 0],
            "upscale_by": 2.5, "seed": seed + 3, "steps": 8, "cfg": 1.0,
            "sampler_name": "euler", "scheduler": "simple", "denoise": tile_denoise,
            "upscale_model": ["13", 0], "mode_type": "Linear",
            "tile_width": 1024, "tile_height": 1024, "mask_blur": 8, "tile_padding": 32,
            "seam_fix_mode": "None", "seam_fix_denoise": 1.0, "seam_fix_width": 64,
            "seam_fix_mask_blur": 8, "seam_fix_padding": 16,
            "force_uniform_tiles": True, "tiled_decode": True, "batch_size": 1}}
        image_out = ["19", 0]
    else:
        wf["14"] = {"class_type": "ImageUpscaleWithModel", "inputs": {"upscale_model": ["13", 0], "image": ["8", 0]}}
        wf["15"] = {"class_type": "ImageScale", "inputs": {"upscale_method": "lanczos", "width": 3840, "height": 2160, "crop": "disabled", "image": ["14", 0]}}
        image_out = ["15", 0]

    # --- face detail (opt-in; on the full-res image, after the tile pass if both) ---
    if face_detail:
        face_text = f"{trigger}, {face_prompt}" if trigger else face_prompt
        wf["9"]  = {"class_type": "CLIPTextEncode", "inputs": {"text": face_text, "clip": ["2", 0]}}
        wf["10"] = {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["9", 0]}}
        wf["11"] = {"class_type": "UltralyticsDetectorProvider", "inputs": {"model_name": "bbox/face_yolov8m.pt"}}
        wf["12"] = {"class_type": "FaceDetailer", "inputs": {
                "image": image_out, "model": model_ref, "clip": ["2", 0], "vae": ["3", 0],
                "positive": ["9", 0], "negative": ["10", 0],
                "guide_size": 1024, "guide_size_for": True, "max_size": 2048,
                "seed": seed + 7, "steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": face_denoise,
                "feather": 5, "noise_mask": True, "force_inpaint": True,
                "bbox_threshold": 0.5, "bbox_dilation": 10, "bbox_crop_factor": 3.0,
                "sam_detection_hint": "center-1", "sam_dilation": 0, "sam_threshold": 0.93,
                "sam_bbox_expansion": 0, "sam_mask_hint_threshold": 0.7, "sam_mask_hint_use_negative": "False",
                "drop_size": 10, "bbox_detector": ["11", 0], "wildcard": "", "cycle": 1}}
        image_out = ["12", 0]

    wf["16"] = {"class_type": "SaveImage", "inputs": {"images": image_out, "filename_prefix": prefix}}
    return wf


if __name__ == "__main__":
    # build.py "<prompt>" <seed> <prefix> [lora] [strength] [trigger] [face] [tile]
    a = sys.argv
    prompt = a[1]; seed = int(a[2]); prefix = a[3]
    lora = a[4] if len(a) > 4 else "whitemage_rank32.safetensors"
    strength = float(a[5]) if len(a) > 5 else 1.0
    trigger = a[6] if len(a) > 6 else "qildra"
    lora = None if lora in ("", "none", "None") else lora
    flags = set(a[7:])
    json.dump(build(prompt, seed, prefix, lora=lora, strength=strength, trigger=trigger,
                    face_detail="face" in flags, tile_detail="tile" in flags), sys.stdout)
