# ADR-0008: Onboarding and globe aids — simpler, not easier

- **Status:** Accepted — 2026-11-14

## Context
A playtester who never played the classic genre found the game unintuitive: unclear which clue answers what, and hard to locate countries such as Hungary on an unlabeled globe.

## Decision
1. **Two questions, always visible.** The notebook is split into *Where did they go?* (wiretap, CCTV, money-to-destination) and *Who is it?* (suspect traits). Suspect clues are tagged with the trait they inform (`[clue about: Vehicle]`), not its value.
2. **Next-step box** on every city screen, driven by game state (investigate → travel → dead end → issue order → arrest).
3. **How to play** screen with five steps.
4. **Country labels on the globe** (Natural Earth names ES/EN, `tools/make_countries.py`), level of detail by zoom and hidden on the far side.
5. **Analyst shortlist**: four countries, one correct. Tapping one spins the globe to it and highlights the name; the player still has to drop the pin. Difficulty is preserved by the decoys: far-away countries in easy cases, the target's nearest neighbours in hard cases.

## Consequences
Every leg of all 15 cases is tested to include the real destination among the four suggestions; hard cases are tested to use nearby decoys.
