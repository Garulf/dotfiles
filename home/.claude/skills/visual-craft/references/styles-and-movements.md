# Styles & Movements

Style names are compressed vocabulary: era + medium + palette + line/brush quality + composition habits in one word. For AI generation, pair the label with a description of the look — labels drift between models, descriptions don't.

## Painting movements — what they LOOK like

| Movement | Visual signature | Names |
| --- | --- | --- |
| Renaissance | linear perspective, realistic anatomy, sfumato haze, religious/classical staging | da Vinci, Michelangelo, Raphael |
| Baroque | violent chiaroscuro/tenebrism, rich darks, diagonal motion, theatrical emotion | Caravaggio, Rembrandt |
| Rococo | pastel palettes, ornament, idealized aristocratic leisure | Fragonard, Boucher |
| Neoclassicism | crisp ordered classical forms, sculptural light | David, Ingres |
| Romanticism | the sublime: vast dramatic nature, tiny awed figures, storm light | Friedrich, Delacroix, Turner |
| Impressionism | loose visible brushwork, fleeting outdoor light, everyday subjects | Monet, Renoir |
| Post-Impressionism | exaggerated expressive color and stroke — impasto swirls or flat symbolic planes | Van Gogh, Gauguin |
| Ukiyo-e | woodblock: bold outlines, flat color planes, compressed space, asymmetric off-center design | Hokusai, Hiroshige |
| Art Nouveau | flowing botanical linework, ornamental borders, flat decorative gold | Mucha, Klimt |
| Fauvism | color unhooked from reality, bold and raw | Matisse |
| Expressionism | distorted form in service of emotion | Munch, Schiele |
| Cubism | fragmented simultaneous viewpoints | Picasso, Braque |
| Surrealism | photoreal rendering of impossible dream scenes | Dalí, Magritte |
| Art Deco | streamlined luxury geometry, gold/black, poster elegance | (Chrysler Building, travel posters) |
| De Stijl / Bauhaus / Constructivism | grid geometry, primary colors, functional or propaganda diagonals | Mondrian, Rodchenko |
| Abstract Expressionism | gestural drips (Pollock) or glowing color fields (Rothko) | Pollock, Rothko |
| Pop Art | flat commercial color, halftone dots, consumer icons | Warhol, Lichtenstein |
| Minimalism / Op Art | essential monochrome forms / optical vibration patterns | Kelly, Riley |
| Photorealism | painting indistinguishable from photograph | Estes, Close |
| Magical realism | mundane realistic scene + one quiet impossibility | Magritte-adjacent, Hopper mood |

Ukiyo-e is the pivotal one for this user's work: its flat planes, bold contour lines, and asymmetric composition are the direct ancestors of anime aesthetics, and via Japonisme it reshaped Western art too.

## Photographers — signature looks

- **Ansel Adams** — large-format B&W landscape, Zone System tonal control, razor deep focus, dramatic skies. Prompt-sense: `black and white large format landscape, dramatic tonal range, sharp front-to-back`.
- **Henri Cartier-Bresson** — Leica street, the decisive moment, geometry + perfect timing, candid humanity.
- **Sebastião Salgado** — epic monochrome humanitarian scale; **Steve McCurry** — saturated color portraiture, piercing eyes.
- **Gregory Crewdson** — staged cinematic suburban tableaux at twilight, eerie stillness, elaborate lighting.
- **Annie Leibovitz** — theatrical staged portraits, painterly controlled light.
- **Irving Penn** — minimalist studio, neutral backdrop, subject as sculpture.

## Cinematographers & directors — signature looks

- **Roger Deakins** — motivated invisible light, minimalist essential frames, atmosphere via haze/smoke, iconic silhouettes (Blade Runner 2049, 1917). Prompt-sense: `cinematic, motivated practical lighting, atmospheric haze, silhouette against orange fog`.
- **Christopher Doyle** — saturated neon color, chiaroscuro interiors, motion blur, handheld intimacy (Wong Kar-wai films). Prompt-sense: `neon-soaked interior, saturated reds and greens, dreamy motion blur`.
- **Gordon Willis** — underexposure, top-lit eyes-in-shadow (The Godfather): power and moral darkness.
- **Emmanuel Lubezki** — natural light only, ultra-wide flowing long takes (The Revenant): visceral immersion.
- **Wes Anderson** (director) — planimetric dead-center symmetry, pastel palettes, flat lateral moves: storybook artifice.

## Using style vocabulary

1. **Anchor**: movement or artist name (`Art Nouveau poster`, `in the style of Caspar David Friedrich`).
2. **Describe**: 2–3 visible traits so the model can't drift (`ornamental border, flowing linework, flat muted golds` / `vast misty mountains, a lone figure seen from behind`).
3. **Medium**: `oil on canvas, visible impasto`, `watercolor wash`, `woodblock print`, `gouache`, `35mm film photograph, grain` — medium words shift rendering more than movement words.
4. Don't stack conflicting anchors (impressionist + art deco + photoreal = mush). One style anchor, one medium, described traits.

## In prompts

- `romanticist landscape painting, vast storm-lit mountains, a tiny figure on the ridge, style of Caspar David Friedrich` — epic scale wallpapers.
- `ukiyo-e woodblock print, bold outlines, flat color planes, great wave composition, asymmetric` — graphic Japanese look.
- `art nouveau poster, ornamental floral border, elegant flowing lines, muted gold and sage palette, Mucha style` — decorative portrait.
- `baroque chiaroscuro oil painting, single candle light, deep shadows` — drama.
- `cinematic still, teal and orange grade, atmospheric haze, motivated neon lighting` — modern film look.
- `impressionist plein air painting, loose visible brushstrokes, dappled afternoon light` — soft painterly warmth.
