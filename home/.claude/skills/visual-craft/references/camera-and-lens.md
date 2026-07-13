# Camera & Lens Craft

Lens and viewpoint choices are meaning choices. Prompt models understand photographic vocabulary — use it precisely.

## Focal length (really: distance) and perspective

Perspective comes from camera-to-subject **distance**; focal length dictates how close you stand, which is why the two are conflated:

- **Ultra-wide / wide (14–35mm)** — you stand close: exaggerated foreground, stretched depth, dramatic converging lines, immersion. Distorts faces up close. The environmental-storytelling and epic-scale lens.
- **Normal (~50mm)** — human-eye perspective, neutral, documentary honesty.
- **Short telephoto (85–135mm)** — flattering facial rendering, background melts: the portrait range. "85mm" is prompt shorthand for a beautiful isolated portrait.
- **Telephoto (200mm+)** — compression: background pulled close, planes stacked flat, subject isolated in a compressed slice. Dense cityscapes, "mountain looming over town" shots, paparazzi voyeurism.

## Depth of field

Shallower with longer lens, wider aperture (f/1.4–f/2.8), closer subject, bigger sensor.

- **Shallow DoF** — subject isolation, intimacy, dreaminess; `bokeh` for the blur quality.
- **Deep focus** — everything sharp: context, ensemble scenes, realism (Citizen Kane, Ghibli vistas).
- **Rack focus** — attention handoff between planes (video).
- **Soft focus** — nothing critically sharp: dream, memory, flashback.
- **Motion**: slow shutter = motion blur, panning streaks, light trails (speed, time); fast shutter = frozen droplets/action (crispness, impact).

## Shot sizes (tight → wide)

| Size | Frames | Use |
| --- | --- | --- |
| Extreme close-up | eyes, mouth, object detail | maximum intensity |
| Close-up | face | emotion, reaction |
| Medium close-up | chest up | face + a little context |
| Medium | waist up | dialogue default, gesture |
| Cowboy | mid-thigh up | swagger, holsters, confidence |
| Full | whole body | physicality, costume, dance |
| Wide / long | subject in environment | context, geography |
| Extreme wide | subject tiny | scale, isolation; the establishing shot |

Framing types: single (clean/dirty), two-shot (relationship, power dynamics), over-the-shoulder (conversation POV), point-of-view (become the character), insert (object detail).

## Camera height & angle (meaning)

- **Eye level** — neutral, objective.
- **Low angle** (looking up) — power, heroism, menace, towering scale. Pairs with wide lens for epic.
- **High angle** (looking down) — vulnerability, smallness, overview.
- **Overhead / bird's-eye / top-down** — pattern, geography, godlike detachment; graphic almost-abstract compositions.
- **Ground / worm's-eye** — extreme up-view: skyscrapers, forest canopy, awe.
- **Dutch angle / canted** — tilted horizon: unease, disorientation, psychological instability.
- **Aerial / drone** — grand establishing scale.

## Movement (video prompts)

- **Static / locked-off** — composure, observation, tableau.
- **Pan / tilt** — reveal, follow; whip pan = frantic energy or transition.
- **Dolly in** — mounting emotion, realization; **dolly out** — abandonment, reveal of context. (Spatial move; a **zoom** is optical and feels synthetic/retro.)
- **Tracking / crab / arc** — travel with the subject; arc reveals the world around them.
- **Dolly zoom (vertigo)** — background warps while subject stays: dread, epiphany.
- **Handheld** — documentary grit, panic, immediacy. **Steadicam/gimbal** — floating smooth pursuit. **Crane/jib** — sweeping rises for openings and finales.

## In prompts

- Lens as shorthand: `shot on 85mm, f/1.8, shallow depth of field, creamy bokeh` (portrait), `ultra wide angle lens, dramatic perspective` (epic/immersive), `telephoto compression, stacked city blocks` (dense flat layers), `macro photography` (extreme detail).
- Size + angle together: `extreme wide establishing shot, a lone figure dwarfed by the cliffs`, `low angle looking up at the mecha, towering overhead`, `top-down overhead shot, geometric patterns of the market`.
- Dutch for tension: `canted dutch angle`; POV for immersion: `first-person POV, hands visible`.
- Video motion: `slow dolly in toward her face`, `handheld tracking shot through the crowd`, `sweeping aerial drone shot rising over the valley`.
- Stills benefit from camera language too — `cinematic still`, `35mm film photography` set overall rendering behavior, not just geometry.
- Wallpaper/vista work: extreme-wide + low camera + strong foreground element is the reliable "epic scale and depth" recipe (matches the krea2 wallpaper prompt structure).
