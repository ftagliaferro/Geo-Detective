# ADR-0012: Travel by selection, more arrest scenes, more clue mini-games

- **Status:** Accepted — 2026-11-16

## Context
Feedback after the modern redesign: the mini-games are great — add variety (clues and arrest); small countries (Netherlands, Austria) are hard to pin because labels cover them, so choosing one of the four suggested countries should be enough to travel; countries with two game cities (e.g. Brazil) make pinning ambiguous — mark the cities.

## Decision
### Travel
- Game cities are drawn on the globe (coral dot + name, decluttered with the country names, cities win).
- Tapping within 26 px of a city dot snaps the pin onto it.
- Picking a suggested country is a valid destination: one game city in that country → the pin goes there; several → *Which city?* buttons; none → the country centre (a miss).
- The pin info shows the destination by name.

### Arrest / escape scenes (`_arrest_kind`)
| Scene | Where | Controls |
|---|---|---|
| Car chase (3D) | default | lanes: arrows/A-D, swipe, tap |
| Canal boat chase (3D, same engine, `set_canal_theme`) | water cities (Amsterdam, Stockholm, Sydney, Istanbul…) | lanes |
| Rooftop foot chase (2D, `roof_chase.gd`) | other cities, alternating | jump: space/up/W/click/tap/JUMP |
All three work inverted in fugitive mode (police behind you, survive the timer).

### Clue mini-games (random per visit)
| Source | Classic | New interactive variant |
|---|---|---|
| Wiretap | Tune the dial | **Voiceprint**: pick the recording that matches the suspect's wave |
| CCTV | Scan & zoom | **Focus**: de-pixelate the photo with a slider |
| Local contact | Dialogue | **Interrogation**: 3 rounds, read the mood (nervous / greedy / proud) and pick the right tone |
| Money trail | Flip receipts | **Order**: tap the transactions chronologically |
Solving any interactive mini-game well and in time makes that clue 1 hour cheaper.

## Consequences
The thief character drawing moved to `ui/thief_art.gd` (shared by cutscenes and the rooftop chase). 339 GDScript tests cover the new chases and mini-game outcomes.
