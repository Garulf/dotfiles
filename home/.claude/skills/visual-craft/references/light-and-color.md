# Light & Color

Light defines form and mood; color defines emotion and cohesion. Both are named systems — use the names.

## Light direction (what each angle says)

- **Front** — flat, shadowless, low drama; hides texture and depth. News/beauty/clean product looks.
- **Side (form light)** — reveals volume and texture; the general-purpose "sculpting" direction.
- **Back** — silhouettes, halos, glowing edges; reveals atmosphere (haze, dust, rain). The romantic/epic direction.
- **Top** — shadowed eye sockets, oppression, interrogation. Harsh midday sun does this.
- **Under** — unnatural, menacing (campfire-horror), because it never happens in nature.

Diagnostic habit: the nose/subject shadow's direction tells you the key's lateral angle; the shadow's length tells you its height.

## Light quality

- **Hard light** (small or distant source: bare sun, bare bulb) — crisp shadow edges, texture, grit, drama.
- **Soft light** (large or diffused source: overcast sky, softbox, window) — gentle gradients, flattering, calm.
- **Key:fill ratio** sets contrast mood: ~4:1 reads natural; 16:1 and beyond reads stylized/noir. **High-key** (bright, low ratio) = optimism, comedy, commercial. **Low-key** (dark, high ratio) = noir, tension, mystery.
- **Motivated lighting** — light should appear to come from sources the scene contains (window, lamp, neon sign). Unmotivated light reads artificial (Deakins' whole method is motivated, invisible light).

## Named portrait patterns (setup → look → connotation)

| Pattern | Setup | Look | Says |
| --- | --- | --- | --- |
| Flat | key near camera axis | shadowless | clean, neutral |
| Loop | ~45° key, slightly high | small nose-shadow loop | flattering, natural default |
| Rembrandt | ~60° key, elevated | light triangle on shadow cheek | drama, gravitas |
| Split | 90° key | half lit / half dark | duality, conflict, villain |
| Butterfly | high frontal key | symmetric under-nose shadow | glamour, beauty |
| Rim | ~120°+ behind | lit edges, dark face | mystery, separation |
| Silhouette | backlight only | pure shape | anonymity, reveal |

Three-point foundation: key (dominant), fill (opposite, controls ratio), back/rim (separates subject from background). Rim light is the single cheapest "make subject pop" tool in any medium.

## Natural light situations

- **Golden hour** — low warm sun, long soft shadows: romance, nostalgia, epic warmth.
- **Blue hour** — cool dim ambient: melancholy, serenity, anticipation.
- **Overcast** — giant softbox: even, muted, honest; great for color subtlety.
- **Hard midday** — top-lit, harsh: grit, fatigue, desert brutality.
- **Window light** — directional soft side light: the painterly interior default (Vermeer).
- **Komorebi / god rays** — light shafts through leaves/clouds/dust: wonder, the sacred.

## Color harmony schemes

- **Complementary** (opposites: orange/blue, red/green) — maximum contrast and tension. Teal-and-orange is the blockbuster grade: warm skin vs cool shadows.
- **Analogous** (neighbors: yellow-orange-red) — cohesion; serene or oppressively uniform depending on value range. (Amélie's warm golds/greens.)
- **Monochromatic** — one hue's tints/shades: unity, focus, mood-soak (Shape of Water greens, Matrix green).
- **Triadic** — three evenly spaced hues: balanced vibrancy, comic/animated energy (The Incredibles).
- **Split-complementary** — base + the two neighbors of its complement: contrast with less violence.

## Color psychology (fast table)

| Color | Says |
| --- | --- |
| Red | passion, danger, urgency, violence |
| Orange | warmth, energy, sunset comfort |
| Yellow | optimism, caution, sickness (desaturated) |
| Green | nature, growth — or unease, poison, the uncanny |
| Blue | calm, sadness, isolation, cold competence |
| Purple | mystery, royalty, the mystical |
| Pink | intimacy, tenderness, artifice |
| White/light | innocence, sterility | 
| Black/dark | power, death, elegance |

Warm advances toward the viewer, cool recedes — usable as a depth tool (warm subject, cool background).

## Building a palette

1. Pick the mood first, then 2–4 dominant colors that carry it. Limiting the palette is what creates cohesion — most muddy images are palette failures, not rendering failures.
2. Reserve one accent color that appears nowhere else, for the subject or story point (Schindler's List's red coat).
3. Saturation axis: high = vibrant, energetic, stylized; desaturated = gritty, desolate, realistic.
4. Value axis: overall bright vs dark is the color-world's high-key/low-key.

Reference grades: La La Land (saturated jewel tones, dream romance), Blade Runner 2049 (neon blue vs furnace orange, dystopia), Grand Budapest (pastels, nostalgia-whimsy), Her (soft pinks/reds, intimacy), Joker (sickly yellow vs gray, alienation), The Revenant (icy desaturated blues, survival).

## In prompts

- Name the pattern and direction: `soft Rembrandt lighting from a window on the left`, `strong rim light separating her from the dark forest`, `backlit, glowing edges, volumetric haze`.
- Name the mood-light: `golden hour, long warm shadows`, `blue hour ambience`, `overcast soft light`, `harsh midday sun`, `god rays through the canopy`, `volumetric lighting` (the all-purpose depth-and-atmosphere phrase).
- Name the ratio: `high-key, bright and airy` vs `low-key, deep shadows, chiaroscuro`.
- Name the palette, limited: `a palette of teal and burnt orange`, `analogous warm palette of golds and ambers with one cyan accent`, `muted desaturated tones` vs `rich saturated colors`.
- Motivate the light: `lit only by the neon signs / the lantern she carries / firelight` — models follow motivated-light instructions well and it instantly unifies a scene.
- One light story per image: contradictory light directions are a top AI artifact — state a single source direction explicitly.
