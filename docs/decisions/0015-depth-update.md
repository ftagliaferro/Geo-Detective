# ADR-0015: Depth update — choices, surprises, a thief who reacts, story, gear, objectives, combined clues, city maps

- **Status:** Accepted — 2026-11-25

## Context
Feedback: "it feels monotonous". Diagnosis: every city plays the same way (four cards, investigate them all, travel); few real decisions; flat tension; nothing unexpected. Points 1, 2, 3, 4, 5, 6, 7 and 9 of the proposal were approved (8 and 10 later).

## Decisions (numbers are the tuning; all in `core/` so they are unit-tested)

### 1. Choosing what to investigate
- **Two investigations per city** before the trail cools (`ACTIONS_PER_CITY = 2`). A third (or fourth) is allowed with the trail cold: **+2 h** each.
- Where-clues have a visible **clarity** and price: *clear* (tier-1 text) 3 h · *medium* (tier 2) 2 h · *vague* (tier 3) 1 h. Each trail city deals its two text sources (wiretap, local contact) two different tiers from the case's difficulty band; the camera is a photo (2 h); the money trail (WHO) 2 h.
- The real decision per city: one clear clue + the money trail, two cheap where-clues to be sure, or skip WHO and risk the board at the end.
- Budgets are recomputed from a new par (clear where + money per trail city, two actions in the final city, exact flights) × the arc's slack.

### 2. Surprise events
- On arrival in a trail city (never the first or the final city) an **event card** may appear: ~40% of cities from case 3 (case 1 none; case 2 exactly one, gentle). Each card has two options with stated costs; some start a mini-game.
- Effect vocabulary (engine): `hours ±n`, `next_flight +n`, `free_action`, `extra_action`, `lose_action`, `eliminate` (two decoys off the analyst list), `reveal_trait` (the next unknown trait of the culprit), `reveal_fact` (a fact about the destination), `minigame` (success / fail effects).
- Deck (data, `events.json`): informant, airport strike, corrupt cop, ambush, anonymous envelope, witness, pickpocket, storm, old colleague, reporter, plus gang-specific cards.

### 3. A thief who reacts
- **Thief's lead** (hours): `lead = case head start + Σ(hours you spent in each city − thief stay 5 h) + wrong flights`. Shown on the city screen ("left 6 h ago" / "still in the city!"). Spending less than 5 h in a city closes the gap.
- Lead ≤ 2 h on arrival → **sighting** mini-game (replaces the random ones; success = 3 h back). Lead ≤ 4 h (from case 3) → the thief **reacts**: an intercepted taunt plus a *reaction card* (tips off police, burns a source, plants a false clue, ambush), never two cities in a row.
- Intercepted messages also taunt after a wrong flight and greet you in boss cases.
- **Each gang has a rule twist**, told in the briefing's gang file and the first time it happens; frequency 1 / 2 / 3 cities over its three cases:
  - Paper Saints — **forged clue**: one text clue in the city points to a decoy country. Cameras never lie.
  - Blue Harbour — **by sea**: that leg has no analyst shortlist; use the globe (pins are generous).
  - Zero Signal — **interference**: the wiretap arrives with words blacked out; 1 h to decrypt.
  - Velvet Hands — **body double**: the camera photo shows a decoy country's city; text clues are reliable there.
  - Glass Serpent — mixes all four.
- One twist per city at most; never a twist and a combined clue on the same source.

### 4. Story
- Cast: **Inspector Marta Rivas** (your boss — the same Rivas who hunts you in fugitive mode), **Nico** (the analyst behind the shortlist), **Dr. Aldo Varela** (Interpol liaison, helpful in briefings), the five gang bosses. Arc: someone is coordinating the five gangs — **the Collector**. Case 15 reveals it is Varela, who escapes: the hook for later content.
- A short dialogue scene (2–4 lines, portraits, tap to advance, skippable) before each case and after each win (`story.json`).

### 5. Gear
- Eight gadgets unlocked by total stars; **two slots** (three from 30★), chosen in the briefing, remembered.
  | Gadget | Unlock | Effect |
  |---|---|---|
  | Interpol contact | 2★ | once per case: two decoys off the analyst list |
  | Forensic lens | 5★ | camera hints always readable; reveals body doubles |
  | Contact book | 9★ | three investigations per city before the trail cools |
  | Private jet | 13★ | once per case: one flight at half the hours |
  | Decoder | 17★ | wiretaps arrive without interference |
  | Lie detector | 21★ | once per case: marks a forged clue in the city |
  | Interpol file | 26★ | start the case knowing one trait of the culprit |
  | Port radar | 31★ | the analyst still suggests countries on sea legs |
- Counters exist for every gang twist, so gear choice matters per gang. Case 1 (tutorial) has no gear.

### 6. Objectives
| Type | Cases | Difference |
|---|---|---|
| Pursuit | 1, 2, 3, 5, 6, 9, 12, 15 | follow, warrant, arrest + chase (as before) |
| Recover the loot | 4, 8, 10 | the money trail describes the **hideout** (zone · kind · detail); the final city is a map of six places; each raid 3 h; first-try raid = third star |
| Rescue | 11, 13 | identify the kidnapper (warrant); the finale is an escape chase with the hostage |
| Two thieves | 7, 14 | mid-route the pair splits; clues point to two destinations (long and short branch); follow either one; each branch's culprit is identifiable from its own trail |

### 7. Combined clues
- Country facts (continent, hemisphere/season, language, currency, driving side) for every country that can be suggested. In some cities (≈30% from case 4, ≈50% from case 10) the two text sources each give **half a clue** (1 h each): each fact alone fits two or more of the analyst's four countries; both together fit only the destination. The camera still works as a tie-breaker.
- The travel screen lists what you know about the destination ("they speak English", "it's winter in July").

### 9. City as a map
- The city screen is a stylised map (district streets, water when the city is coastal or on a river, the landmark) with **places**: Hotel (wiretap), Main avenue (cameras), Café (contact), Exchange office (money), Airport (travel). Tap a place to see clarity, cost and result. A list under the map mirrors the places (phones, accessibility, tests).
- Recover cases reuse the map for the six hideout candidates.
- Pins are laid out in pixels once the map's size is known: each takes the nearest free spot to its ideal position (growing-ring search), with two fallback strategies; if the names can't all fit (long names on a small phone map), only the pins/letters are drawn and the list names every place. The landmark is placed first when the pins still fit around it, otherwise in the room left, otherwise left out. Layouts are cached per city and size. `tests/city_map_check.gd` asserts: no overlap, inside the map, on land, and names + landmark always shown on wide maps.

## Fairness rules (asserted by tests)
- A forged/double clue never sits alone: the city always has at least one truthful where-source of each other kind.
- Combined-clue pairs are verified per leg (each half ambiguous, both unique) or the city falls back to normal clues.
- Every case and branch is winnable by a par player with ≥ 10% hours left under the safe event choices; trait/hideout clues identify the target when all trail WHO-clues are collected; no event can soft-lock (negative actions clamp, hours never below zero, the analyst list never empties).
- Tutorial (case 1) has no events, twists, reactions or gear; first-time tips explain each new mechanic once.

## Consequences
- `CaseState` grows (actions, events, lead, twists, gear, objectives, facts); the UI's city screen is rebuilt around the map. Fugitive mode is unchanged in this update.
