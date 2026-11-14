# Game Design Document — Geo Detective *(working title)*

> Version 0.1 — 2026-11-14 · Status: draft for review

## 1. Pitch
You are a field agent of a fictional international task force. Crime networks — cartels, con artists, hackers, traffickers — are moving across the world. Follow their trail city by city, read the clues (people, places, street scenes), build the suspect's profile and issue the arrest order **before the clock runs out**.

**Pillars**
1. **Learn the world by playing** — every clue is a real geographic fact or a real street scene.
2. **Deduction, not luck** — the player wins by reasoning; guessing costs time.
3. **Short, arcade sessions** — one case = 8–15 minutes; perfect for mobile.
4. **Retro-noir with a modern finish** — low-poly 3D, neon/CRT UI, synthwave sound.

## 2. Core loop (one case)
```
Briefing ─► Investigate city ─► Read clues ─► Update deduction board
   ▲                                              │
   │                         Travel (3D globe) ◄──┘
   └──── Final city: issue arrest order ─► Arcade chase ─► Results
```
1. **Briefing:** crime, origin city, time budget (e.g. 120 in-game hours), gang file.
2. **Investigate:** each city has 3 spots. Each visit costs hours.
   - **Witness** — text clue about the next destination ("She asked for change in *forints*").
   - **Informant** — clue about the suspect ("He never takes off his gold signet ring").
   - **Street look** — a curated street image of the *next* destination; optional hint highlights what to look at (plates, signs, script, driving side). Easy GeoGuessr.
3. **Travel:** on the 3D globe choose among 4 destinations. Travel cost depends on distance. Wrong city → dead-end clues ("Nobody here saw anyone like that") and time lost.
4. **Deduction board:** 5 suspect traits (specialty, vehicle, distinctive mark, language, hobby). Filtering narrows the gang roster. An **arrest order** must be issued before the final city.
5. **Arcade chase (final city):** a 30–45 s low-poly chase (rooftops / streets / harbour). Success depends on the arrest order being correct; skill only adds bonus stars.
6. **Results:** 1–3 stars (time left, wrong trips, chase), XP toward rank.

**Lose conditions:** time runs out, or arrest order wrong/missing at the end.

## 3. Structure & progression — 15 cases (v1)
Five fictional crime networks × 3 cases each; the 3rd case of each arc is the network's lieutenant/boss.

| Arc | Network (working name) | Crime | Cases | Hops | Suspects |
|---|---|---|---|---|---|
| 1 | *The Paper Saints* | Forgers & con artists | 1–3 | 3–4 | 4 |
| 2 | *Blue Harbour Syndicate* | Smuggling routes | 4–6 | 4–5 | 6 |
| 3 | *Zero Signal* | Cyber-crime & crypto scams | 7–9 | 5 | 6 |
| 4 | *Velvet Hands* | Art & antiquities traffic | 10–12 | 5–6 | 8 |
| 5 | *The Cartel of the Glass Serpent* | Cartel finale | 13–15 | 6–7 | 8 |

*Names are placeholders and will be checked against existing trademarks/fiction before release (ADR-0003).*

**Difficulty curve**
- Cases 1–3: famous landmarks & flags, hints free, generous time. Tutorial inside case 1.
- Cases 4–9: currencies, languages, food; street look without free hints.
- Cases 10–15: scripts, regional details, decoy clues, tighter time.

**Ranks:** Rookie → Field Agent → Inspector → Senior Inspector → Commander → Director.

## 4. Content model (data-driven, engine-independent — ADR-0002)
- `cities.json` — ~40 cities in v1: id, name (es/en), country, lat/lon, clue pools by category & difficulty, street-look image ids.
- `suspects.json` — fictional characters with 5 traits, portrait id, network.
- `cases.json` — hand-authored: route (city ids), culprit, time budget, decoys, difficulty.
- `streetlook.json` — image file, source, author, license, "what to look at" (es/en).
- `i18n/` — UI strings es/en.
Python tools validate everything (routes reachable, clues exist for each hop, licenses present, both languages complete).

## 5. Art & audio direction
- Low-poly 3D globe with stylized continents; flight arcs in neon.
- UI: noir dossier aesthetic — paper files, stamps, mugshot frames, CRT scanline filter (toggleable).
- Arcade chase: low-poly city blocks, chunky retro lighting.
- Music: synthwave/noir loops; original or CC0, logged in `CREDITS.md`.
- Godot Compatibility renderer — must run on low-end PCs, phones and browsers.

## 6. Monetization (ADR-0001 scope)
- **Free version:** AdMob banner on menu, map/globe and results screens. Never over clues or during the chase.
- **"Remove ads"** one-time purchase (≈ USD 2.99), restorable.
- *Proposed, not decided:* optional rewarded ad "+6 hours" when time runs low.

## 7. Platforms & tech
- Godot 4 / GDScript, single project → Windows, Linux, Android, Web (itch.io); iOS via GitHub Actions macOS.
- Core rules in engine-agnostic scripts (`game/core/`) with unit tests; scenes only present data.
- Save: local file (progress, stars, purchase flag); no account needed in v1.
- Languages: Spanish & English, switchable in settings.

## 8. Rating & content guardrails (ADR-0004)
Crime-thriller tone; no graphic violence, no depiction of drug use, no real people/organizations. Target ESRB Teen / PEGI 12–16.

## 9. Vertical slice (next milestone)
Case 1 playable end-to-end in the browser: 3 cities, 4 suspects, witness + informant + street-look clues, deduction board, arrest order, results screen. Placeholder art allowed. Chase = simple placeholder.

## 10. Open questions
- Final title & agency name.
- Rewarded ad "+6 hours": yes/no.
- Chase controls on PC (keyboard) vs mobile (swipe).

---
## 🇪🇸 Resumen
Sos agente de una fuerza internacional ficticia. En cada caso seguís a una banda por el mundo: en cada ciudad investigás 3 lugares (testigo, informante y una **foto de la calle** del próximo destino), viajás en un globo 3D, completás el tablero de deducción, emitís la orden de captura y terminás con una **persecución arcade** corta. 15 casos en 5 bandas (estafadores, contrabando, hackers, arte, cartel final), con dificultad creciente y rangos de detective. Anuncios solo en menús, mapa y resultados; compra única para quitarlos.
