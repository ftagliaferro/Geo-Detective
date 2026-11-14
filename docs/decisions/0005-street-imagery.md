# ADR-0005: "Street look" clues — curated imagery, not live Google Street View

- **Status:** Accepted — 2026-11-14

## Context
We want GeoGuessr-style clues (an easy version): the player sees a street scene and recognizes the country from road signs, plates, driving side, bollards, script, architecture.

## Options
| Option | Pros | Cons |
|---|---|---|
| Live Google Street View (Maps Platform) | Huge coverage, familiar | Paid per load after free quota → cost grows with players; API key shipped inside the app; terms forbid caching/offline; needs internet |
| **Curated, openly licensed photos** (Mapillary CC-BY-SA, Wikimedia Commons, own photos) | Free per play, works offline, we hand-pick images where the clue is *clear* (better for an "easy" mode), full control | Must curate & credit each image |
| Hybrid | Curated by default, optional Street View later | More work |

## Decision
Curated, openly licensed street images bundled with the game, each tagged with what to look at (e.g. "yellow UK plates on the rear, driving on the left"). Optional live Street View can be evaluated after launch once revenue covers API cost. Each image logged in `CREDITS.md` with author and license.
