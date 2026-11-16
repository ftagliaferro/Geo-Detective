# ADR-0011: Modern UI and an action layer

- **Status:** Accepted — 2026-11-16

## Context
Playtest feedback: "the gameplay lacks dynamics and action; I want to see the thief escaping, the interaction when asking for clues is flat, and the interface doesn't appeal — make it modern, but not futuristic/purple".

## Decision
### Visual design system (`ui/style.gd`)
- Light, warm background (#F5F2EC), white rounded cards with soft shadows, one coral accent (#FF5A3C), deep navy ink, sky blue for *where* clues and rose for *who* clues. No purple/neon.
- Fonts (OFL): **Outfit** for display, **Inter** for UI, **JetBrains Mono** for evidence, loaded as variable fonts with explicit weights.
- Flat modern globe texture, pastel daylight chase, screen fades and staggered card entrances (`ui/fx.gd`).

### Interaction when asking for clues (`ui/clue_reveal.gd`)
| Source | Interaction |
|---|---|
| Wiretap | Tune a dial until your wave matches the intercepted signal — done within 7 s it costs **1 h less** |
| CCTV | Real photo with scan line, zoom-in and REC overlay |
| Local contact | Portrait and speech bubble with typed text |
| Money trail | Receipts flip one by one with coin sounds |
| Boss (fugitive) | Phone chat with "typing…" then the coded message |

### The thief on screen (`ui/cutscene.gd`)
A recurring character (fedora, dark trench coat, coral scarf) drawn in code, in short skippable vignettes over a skyline generated per city: heist on the rooftops, plane take-off, car getaway, rooftop run, arrest under police lights, safe-house door. Also used as looping hero banners.

### Action events (`ui/minigame.gd`)
- **Sighting** (detective, scheduled on some legs): tap the suspect 3 times as they peek from windows → recover 3 h.
- **Passport control** (fugitive, on some arrivals): stop the needle in the green zone → fail = 3 h delay.
Both are deterministic per case/escape seed and unit-tested (`resolve_sighting`, `resolve_checkpoint`).

### Sound (`tools/make_sfx.py`, `ui/sfx.gd`)
Fifteen original synthesized effects (clicks, radio static, lock tone, shutter, coins, plane, siren, stamp, success/fail…), pooled player, mute toggle.

### Feedback & recap
Flight preview arc when the pin drops, low-time warning on the clock, camera shake on chase hits, route recap globe on the results card.

## Tooling
- `tests/smoke_ui.gd` now drives overlays, cutscenes and mini-games (CI).
- `tests/screenshot_tour.gd` renders every screen under `xvfb` for visual review and README screenshots.
