# Anime Art Styles

Anime is not one style. The axes that actually differentiate looks: shading approach, line quality, eye/face convention, palette, and background treatment. Name these and you control the output; say only "anime style" and you get the model's average.

## Shading approaches (the biggest lever)

- **Cel shading (flat/toon)** — light quantized into 2–3 hard-edged tone blocks; shadow tone slightly darker *and cooler* than base; no gradients or bloom. The classic TV anime look. Prompt: `flat cel shading, two-tone shadows, clean lineart`.
- **Painterly anime** — soft brush transitions, hue shifts within skin, visible strokes in hair/fabric/background; looks hand-painted. The splash-art / key-visual / light-novel-cover look. Prompt: `painterly semi-realistic anime illustration, soft rendering, visible brushwork`.
- **90s retro cel** — film grain, muted earthy palette, thicker lines, simpler single highlights, hand-painted backgrounds (Cowboy Bebop, Evangelion). Prompt: `1990s retro anime style, film grain, muted colors, cel animation look`.
- **Modern digital TV** — crisp thin lines, gradient-accented cel shade, glow/bloom compositing, saturated. Today's default.
- **Rim light rule** — a warm rim light against a cooler ambient is the fastest way to make a flat-shaded character read three-dimensional and pop off the background. Anime leans on this constantly.

## Studio signatures

| Studio | Look | Prompt-sense |
| --- | --- | --- |
| Ghibli / Miyazaki | painterly gouache backgrounds, lush nature, round soft faces, modest eyes, natural palette, no neon | `Ghibli-style, hand-painted watercolor backgrounds, soft natural colors, lush detailed nature` |
| Kyoto Animation | "soft realism": photographic DoF/bokeh/lens glow, delicate hair & fabric, warm golden light, quiet nuance | `delicate anime style, soft focus, golden hour glow, bokeh, detailed flowing hair` |
| ufotable | cinematic high-contrast digital lighting, 2D/3D blend, particle effects, saturated glows | `cinematic anime, dramatic high-contrast lighting, glowing particle effects` |
| Trigger | jagged energetic lines, flat neon pop-art color, impact frames, physics-defying poses | `bold graphic anime style, neon flat colors, dynamic exaggerated pose, thick angular lineart` |

Mangaka-flavored styles: Toriyama (sharp features, round musculature), Araki/JoJo (fashion-model poses, bold clothing patterns, dramatic hatching), Oda (rubbery exaggeration).

## Demographic/genre conventions

- **Shōnen** — vibrant color, bold lines, dynamic action poses, speed lines, impact frames.
- **Shōjo** — soft palettes, slender delicate features, huge luminous eyes, flower/sparkle motifs.
- **Seinen** — realistic proportions, detailed rendering, darker desaturated palettes (Berserk, Vinland Saga).
- **Moe/kawaii** — rounded youthful faces, big eyes/small nose-mouth, pastel cheer.
- **Chibi / super-deformed** — huge head on tiny body, no nose; comedic inserts.
- **Current trends** — webtoon influence (sharp chins, high-contrast glow), sketchy chaotic linework (Dandadan/JJK), hyper-detailed "jewel eyes" (galaxy pupils, stacked highlights).

## Anime composition & lighting conventions

- **Figure-ground by construction**: detailed painterly background + flat-shaded outlined character = the character always reads instantly. Preserve this contrast; prompting everything equally detailed loses the anime read.
- **Sky as emotion**: towering cumulus, sunset gradients, star fields — anime uses the sky as the mood canvas; give it frame area.
- **Komorebi and god rays**; lens-flare and bloom accepted as style, not error.
- **Evening orange** (the "5pm chime" palette) = nostalgia/melancholy; blue-night scenes stay readable via moonlight rim.
- **Action grammar**: low angles, dutch tilts, extreme foreshortening (fist toward camera), speed lines, 1–2-frame high-contrast impact frames.
- Ancestor DNA from ukiyo-e: bold contours, flat planes, asymmetric off-center composition (see styles-and-movements.md).

## In prompts

- Always specify: shading (`flat cel shading` / `painterly`), line (`clean thin lineart` / `bold angular lines` / `sketchy rough lines`), palette (`pastel` / `neon` / `muted 90s`), and background treatment (`detailed hand-painted background`).
- Era/studio words are strong compressed tokens — combine with described traits: `90s retro anime, film grain, muted palette` beats either half alone.
- Character pop: `warm rim light along her silhouette, cooler ambient background`.
- Wallpaper vistas: `breathtaking anime scenery, towering clouds, detailed painted background, character small in frame` — scenery-first framing with the figure as accent (consistent with the krea2 wallpaper recipe's scene part).
- Faces degrade fastest: if the render's face is off, add `detailed beautiful anime face, clean facial features` and reduce competing detail elsewhere in the prompt.
