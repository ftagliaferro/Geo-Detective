# ADR-0009: UI redesign, fourth evidence source, longer cases

- **Status:** Accepted — 2026-11-14

## Context
Feedback: "still not intuitive enough, the interface is ugly, add clues, catching criminals should take more trips".

## Decision
- **Screen-specific layouts** instead of a generic two-column form: top bar with case title and an hours bar; each screen builds its own layout.
- **City screen:** banner cropped from the atlas around the city (name, country, trail status), a *Next step* strip, four **evidence cards** that each state the question they answer (*Where did they go?* / *Who is it?*) and show the clue inside the card (CCTV photo included), and a bottom action bar with one primary action.
- **Dossier-style briefing and results** (paper card, stamp, chips, drawn stars, culprit portrait); menu with rank card and big buttons; case select as cards per gang.
- **Vector icons drawn in code** (`icon_view.gd`) — no external icon assets.
- **Fourth evidence source — Local contact** (3 h): a destination clue from a tier just outside the case's range (an easier one in hard cases, a cultural one in easy cases).
- **Longer routes:** 4 → 11 cities (was 3 → 8). Time budgets are recomputed from the perfect run (now 9 h of evidence per city).

## Consequences
188 GDScript tests (including full playthroughs of all 15 cases with the new source); README, GDD and devlog updated.
