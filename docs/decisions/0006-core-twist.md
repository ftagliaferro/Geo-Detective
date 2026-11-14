# ADR-0006: Core twist — evidence, pin-drop pursuit and the corkboard

- **Status:** Accepted — 2026-11-14

## Context
Playtest feedback on the vertical slice: "it feels too close to the classic geography-chase games". Witness/informant dialogue + choosing from a list of 4 cities + a trait-based warrant is the genre's best-known formula. We keep the genre, but change *how the player reasons and moves*.

## Decision
1. **Pin-drop pursuit instead of a city list.** There is no menu of destinations. The player rotates a 3D globe and drops a pin where they think the suspect went. If the pin lands within the case's *precision radius* of the real city, the agent arrives on the trail; otherwise they land in the nearest other city and find nothing. Precision (km off) feeds the score — a GeoGuessr-style skill layer.
2. **Forensic evidence instead of witnesses.** Each city offers three evidence sources, modern crime-thriller style:
   - **Wiretap** — a transcript of an intercepted call: hints about the next destination.
   - **Money trail** — receipts, card payments, crypto transfers: reveals a suspect trait.
   - **CCTV** — a real street photo of the *next destination* (easy-GeoGuessr), timestamped like surveillance footage.
3. **Corkboard instead of a warrant form.** Suspects are pinned as cards on a corkboard. Evidence lets the player cross out suspects; the last one standing gets the arrest order. Visually and mechanically closer to a crime-drama investigation wall.
4. **Arcade chase finale** (already planned) stays as the signature action moment.

## Consequences
- Travel options are no longer authored per case; `decoys` are removed. Misses land on the nearest city in a world pool of ~35 cities.
- Each case defines `radius_km` (smaller = harder) — a natural difficulty knob across 15 cases.
- Score/stars combine time left, misses and average pin precision.
