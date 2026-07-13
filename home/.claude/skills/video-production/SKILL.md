---
name: video-production
description: Use when producing a multi-shot video, short film, animation, or music video — anything needing a script, concept art, storyboards, or shot assembly on the ComfyUI server.
---

# Video Production Pipeline

Turns an idea into a finished video the way a real production does — development → pre-production (script, look development, concept art, storyboards) → production (shoot) → post (edit, sound, delivery) — through staged deliverables, each signed off by the user before the next stage begins. All generation goes through the comfyui skill (`~/.claude/skills/comfyui/`); assembly uses ffmpeg.

**The user is the director. Violating the letter of a gate is violating their direction.**

## When to use / when NOT to use

**Use** for multi-shot narrative work: short films, music videos, animation, ads, anything needing a script → concept art → storyboard → shot assembly.

**Do NOT use** for a one-off image or a single quick clip with no story, no recurring characters, and no editing — go straight to the comfyui skill instead. This pipeline's gates and consistency machinery are overhead you don't want for a single render.

## Pipeline

1. **Setup** — create a project directory per `references/project-structure.md`. **Refresh first:** the model landscape changes monthly, so web-search the current best-in-class image and video models and ComfyUI conventions for *this kind* of video before committing (how in `references/production.md`). Capability check: `comfy.py stats`; `comfy.py nodes --search ltx` (also `wan`, `hunyuan`, `cogvideo`, `svd`, `animatediff`, `vhs`) for video and (`ace`, `audio`, `tts`) for audio; `comfy.py models`. No video nodes → stop and tell the user before any creative work. Then choose checkpoint/LoRAs/video node for the story from what's installed — selection criteria (character consistency, cinematic style, style consistency, motion) in `references/production.md`. **Default to LTX 2.3 + LTX Director for video unless both discovery and the web turn up something clearly, substantially better that is actually installed** — a marginal edge is not worth breaking the pipeline's tested path.
2. **Treatment** — write `script.md`: premise, character/setting roster, numbered shot list (description, duration, camera). 🔒 **GATE 1**
3. **Concept art (look development)** — start with a **style sheet**: one or a few look-dev frames that fix the film's palette, lighting, and render style; every other item and keyframe is generated to match it (palette/lighting/style vocabulary and shot language: the `visual-craft` skill). Then one reference per setting and key prop, and a **character sheet** — a multi-angle turnaround (front, 3/4, side, back) at consistent scale — for every character that recurs or is seen from more than one angle (txt2img); if the character emotes, add the expression row as a **separate** detail sheet, never in the same image as the turnaround (verified failure — the `character-sheets` skill documents it and has the working two-sheet procedure; use that skill for sheet generation). A bit character seen once from a single angle, a setting, or a prop stays one image. Record prompt, seed, checkpoint, LoRAs, style-sheet link, and (for sheets) which views per item in `concept/manifest.json`. Send the batch. 🔒 **GATE 2** — feedback is per item; regenerate rejected items until all are approved.
4. **Storyboard** — one keyframe per shot, reusing each approved item's recorded prompt fragments/seed/models and matching the approved style sheet. Send numbered frames + a contact sheet. 🔒 **GATE 3**
5. **Production (shoot + post)** — per-shot clips (image-to-video from approved keyframes when the server supports it, else t2v); audio via discovered audio nodes (none installed → ask, and offer to download one onto the server — audio models are the most commonly missing, see `references/production.md`); edit and assemble with ffmpeg per `references/production.md`. Deliver the final cut as a **new, versioned** file — never overwrite a delivered final. 🔒 **GATE 4** — get explicit final acceptance and log it.

**Self-review is part of every stage.** You are the first reviewer of everything the server produces — see the section below.

## Gates

At each 🔒 (including **GATE 4**, final delivery): send the deliverable files to the user, ask for explicit approval, and log it in `approvals.md` (date, gate, scope, the user's verbatim response). Only an explicit yes counts. Feedback → revise → re-present the whole gate. Never start the next stage's generation before the current gate is logged. Final acceptance is a real gate, not a courtesy — log it like the rest.

| Rationalization | Reality |
|---|---|
| "User is in a hurry — skip a gate" | Gates are the product. A fast wrong video is slower. |
| "The art is obviously good enough" | The director decides, not you. Present it. |
| "Combine two gates into one review" | A storyboard built on unapproved art gets rebuilt. |
| "Their earlier message already implied approval" | Approval is explicit, per gate, after seeing the deliverable. |
| "Generate the next stage while waiting" | Never generate stage N+1 material before gate N is logged. |

## Self-review — you are the first reviewer

Before any generated artifact reaches the director, **look at it yourself** (Read the image; for a clip, extract first/mid/last frames or a filmstrip — recipes in `references/production.md`) and scrutinize it. AI generation routinely produces defects; assume there is one until you've checked. Run down this list every time:

- **Hands and fingers** — count the fingers; watch for a duplicated/merged hand, six fingers, fused or bent-wrong digits. The single most common failure.
- **Anatomy** — extra or missing limbs, a second arm/leg, warped or asymmetric faces, wrong eye count, melted ears, impossible joints.
- **Props / weapons** — arrow count, fletching at the nock (not mid-shaft), a metal head (not feathers) at the tip, blade shape, object count.
- **Artifacts / glitches** — smears, warping, garbled text, duplicated objects, background melt, seams, checkerboard/noise patches.
- **Continuity** — match against `concept/manifest.json` and the approved **style sheet**: palette, lighting, wardrobe, character identity.
- **Clips only — temporal defects** — flicker, morphing/identity drift between frames, popping limbs, objects appearing/vanishing, and whether the motion matches the intended camera/action.
- **Craft** — run the `visual-craft` skill's critique pass (subject readability, eye path, one light story, palette, depth): a defect-free frame can still be a weak image.

**Any defect on this list → regenerate** (or surgically fix per `references/production.md`); do not pass a known-broken frame through as "close enough." Never send a file to the user as a passthrough.

Then, for each item:

- **Looks right** → send it, and say briefly why it works.
- **Has an issue** → do all three, in this order: (1) **name the flaw** in your own words ("she has two arrows nocked; the tip lighting is off"), (2) **still send the preview** — the director may accept it, disagree, or steer the fix, (3) **try again** (regenerate or, for a localized flaw, an img2img/edit pass — see `references/production.md`). Present the retry alongside or after the flagged original.

| Rationalization | Reality |
|---|---|
| "The render looks fine, just send it" | You haven't looked until you've *looked*. Inspect every frame before the director does. |
| "It has a flaw — I'll quietly regenerate and only show the good one" | Flag what you see **and** send the preview **and** retry. Hiding attempts hides the problem and wastes the director's steer. |
| "It's close enough, the director won't notice" | If you noticed, name it. They decide what's good enough, not you. |
| "Re-rolling the whole frame is the only fix" | Localized prop/anatomy flaws are usually faster to fix with an img2img/edit pass that preserves the rest. |

## Red flags — STOP and go back to the gate

- Running txt2img with no approved script in `approvals.md`
- Generating concept art before a style sheet exists to match it to
- Building storyboard frames from unapproved concept art
- Submitting video workflows with an unapproved storyboard
- Reading "make it quick" as permission to skip a gate
- Sending a generated image or clip you haven't looked at yourself
- Passing a frame with a visible hand/anatomy/artifact defect as "close enough" instead of regenerating
- Delivering the final cut without logging GATE 4 acceptance
- Overwriting a previously delivered `final/` cut instead of writing a new versioned file

## Consistency

Every downstream generation of a character or setting reuses its exact recorded prompt fragments, seed, checkpoint, and LoRAs from `concept/manifest.json`, and matches the approved **style sheet** for palette/lighting/render. Character sheets are the anchor: when a shot needs a specific angle, pull the matching view from the approved sheet (crop it, or feed it to a reference-image node) instead of re-inventing the character. Techniques and ffmpeg recipes: `references/production.md`.
