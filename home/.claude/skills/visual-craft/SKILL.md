---
name: visual-craft
description: Use when composing, critiquing, or reviewing any image or video frame — writing an image/video generation prompt, judging a render before sending it to the user, choosing framing, lighting, palette, lens, or art style, or when a user asks why an image looks flat, cluttered, boring, or "off".
---

# Visual Craft

## Overview

How images work: composition, light, color, lens, and style — and how to turn that theory into critique language and generation-prompt language. Depth lives in `references/`; this file is the method.

| Question | Reference |
| --- | --- |
| Where do elements go? Why does the eye wander? | `references/composition.md` |
| What mood does the light/palette create? | `references/light-and-color.md` |
| What lens, angle, shot size, movement? | `references/camera-and-lens.md` |
| What named style/artist gets this look? | `references/styles-and-movements.md` |
| Anime-specific shading, studio looks, conventions | `references/anime-styles.md` |

Each reference ends with an **In prompts** section — read it when writing generation prompts.

## Reading an image (critique method)

Work through these in order; each step names the reference with depth:

1. **Subject** — what is this image OF? Can you tell within one second? If not: figure-ground failure (composition).
2. **Eye path** — where does your eye land first, and where does it travel? Bright/saturated/high-contrast/face areas pull first. Does the path stay in frame and end on the subject, or leak out an edge? (composition)
3. **Light** — where is the key light, how hard, what ratio? Does the mood of the lighting match the intent of the image? (light-and-color)
4. **Color** — name the harmony scheme (complementary, analogous, mono). 2–4 dominant colors or a mess? Warm/cool serving the mood? (light-and-color)
5. **Depth & lens** — layered foreground/midground/background or flat? What "focal length" does the perspective imply, and does it suit the subject? (camera-and-lens)
6. **Balance & intent** — visual weights balanced (or deliberately not)? Does every element earn its place? What is the image trying to make the viewer feel — and does each choice above serve that?

**Squint test:** blur the image (squint, or scale it tiny). The composition skeleton — masses, values, eye path — must still read. If it dissolves into noise, the composition is weak no matter how good the details are.

## Applying it to generation prompts

Prompts fail visually for one of these reasons; prescribe from the matching domain:

| Symptom in output | Fix vocabulary from |
| --- | --- |
| Subject lost in clutter, no focal point | composition — negative space, figure-ground, placement |
| Flat, no depth | camera-and-lens (wide angle, layers) + light-and-color (atmospheric haze, rim light) |
| Boring, static, "AI-centered" look | composition — off-center placement, diagonals, asymmetric balance |
| Wrong mood | light-and-color — lighting pattern + palette words |
| Generic style mush | styles-and-movements / anime-styles — name the look AND describe it |

Describe the **look**, not just the label: "flat cel shading, two-tone shadows" beats "anime style"; "loose visible brushwork, fleeting dappled light" beats "impressionist". Labels drift between models; descriptions don't.

## Pre-send self-review checklist

Before sending any generated image to the user, run steps 1–6 above on it, plus:

- [ ] Subject readable at thumbnail size (squint test)
- [ ] Nothing important crowded against an edge or corner
- [ ] One light direction story — no contradictory shadows
- [ ] Palette is 2–4 dominant colors, accents deliberate
- [ ] Depth cue present (layers, haze, DoF, or converging lines) unless flatness is the style
- [ ] The requested mood is what the light + color + angle actually say
