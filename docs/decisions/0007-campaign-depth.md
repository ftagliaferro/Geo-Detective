# ADR-0007: Full campaign and difficulty model

- **Status:** Accepted — 2026-11-14

## Context
Feedback on the demo: "make it fully playable and deeper — more cases, longer cases, more clues that are harder to find, more graphics". The demo is preserved on the `demo-v0.1` branch.

## Decision
- **15 cases / 5 gangs** (3 cases each, the third against the gang boss), routes of 3 → 8 cities, 39 destination cities with hand-written clues.
- **Content as code:** `tools/campaign_content.py` holds the writing; `tools/generate_campaign.py` builds the JSON deterministically. Suspect traits are found by a seeded search so every case is solvable from the trail, but the culprit only becomes unique at the last hop before the final city.
- **Difficulty levers** (all data-driven, per case):
  | Lever | Arc 1 → Arc 5 |
  |---|---|
  | Wiretap clue tier (1 obvious · 2 cultural · 3 subtle) | 1 → 3 |
  | Pin margin | 1000 km → 350 km |
  | CCTV hint | free → must be analysed (+1 h) |
  | Time slack over a perfect run | ×2.2 → ×1.35 |
  | Suspects per gang | 6 → 8 |
- On routes longer than 6 cities the money trail points to the destination once all five traits are known.
- **Progression:** stars saved locally (`user://progress.json`), case N unlocks after N-1, six detective ranks.
- **Stars:** 1 for solving, +1 with no missed pins, +1 for winning the chase.

## Consequences
New tests simulate a perfect playthrough of all 15 cases and assert each is solvable; the Python validator checks tiers, radii and uniqueness.
