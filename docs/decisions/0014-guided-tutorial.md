# ADR-0014: Guided tutorial and plain-language instructions

- **Status:** Accepted — 2026-11-17

## Context
Feedback: "it should be more intuitive; the instructions aren't clear; someone who doesn't know Carmen Sandiego can't play it". The game explained itself with a text-heavy *How to play* page and briefing objectives that assumed the genre (clues → destination, money trail → suspect traits, warrant before arrest). Players who skip reading — most players — had no way to discover the loop.

## Decision
**Learn by doing.** The first case and the first escape are played with a guide (`ui/coach.gd` + the tutorial section of `main.gd`):
- A bubble says, in one or two plain sentences, what to do and why; a pulsing spotlight marks the exact button. It quotes the real button labels (filled in at runtime, both languages).
- The first clue is *explained with its answer*: "The clue says “The contact waits by the Belém Tower”. That's Lisbon, in Portugal: that's where the thief went!" — the key insight of the genre. The money trail is introduced as "WHO, not WHERE"; the board explains ✓/✗ and points at the suspect to cross out.
- First trip: the guide points at the right country chip (and the city, for countries with several), then at *Fly*. Later trips the player decides alone; the guide only reminds the loop.
- Fugitive guide: lead = hours ahead, decode the boss's message (explained with its answer), the smuggler's map, time costs, flee.
- **Never blocking.** Taps go through to the real UI; only the bubble catches touches. "Read this" steps wait for *Got it*; action steps advance when the game state changes. The bubble places itself where it does not cover the target (side columns on landscape/desktop, top or bottom band on portrait).
- **State-driven, not scripted.** Each step is computed from the game state (`_tut_step`), so wrong turns are handled: a wrong city → "go back to X"; a matching suspect crossed out by mistake → "bring them back"; not enough evidence → "investigate another clue".
- Starts automatically the first time (case 1 / escape 1 until finished or skipped, saved in `progress.flags`), from the menu's **First time?** card, and from **How to play → Learn by playing**. *Skip guide* is always there.

**Plain language everywhere.** *How to play* rewritten as 5 short steps with an example ("the Eiffel Tower → Paris, France") plus a "no geography knowledge needed" intro; briefing objectives, next-step hints, globe help and mode descriptions simplified; the travel button now says **Travel** instead of "Track on the globe".

## Verification
`tests/tutorial_flow.gd` plays the first case and the first escape doing only what the guide says (pressing its target or *Got it*; on legs where the player decides alone, picking the destination like a player). It requires a win in both, and for every step: target present, on screen and pressable, bubble inside the screen and not covering the target, text complete. Runs in CI on desktop, 360×740 and 844×390; with a display it saves a screenshot per step (44 steps).
