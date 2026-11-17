# ADR-0013: Phone layout (responsive UI)

- **Status:** Accepted — 2026-11-17

## Context
Feedback: "when I open it on my phone everything looks tiny". The UI was designed for a 1280×720 logical canvas with `canvas_items` stretch. On a phone browser (≈390×844 CSS px, portrait) that canvas is scaled down to fit the width, so 15 px text renders at ~4–5 CSS px. Zooming the whole canvas would not help: a two-column desktop layout simply does not fit a portrait phone.

## Decision
One app, two layouts, chosen at runtime (`main.gd`, `_update_layout_mode`):

- **Detection.** Window size in CSS-like pixels = physical pixels ÷ `screen_get_scale()` (the browser's `devicePixelRatio`; on Android/iOS, dpi ÷ 160). Narrower than 820 or shorter than 520 CSS px → **phone**. A 1024×768 tablet or any desktop browser keeps the desktop layout.
- **Scale.** On phones `content_scale_size` = the CSS size, so one logical pixel ≈ one CSS pixel. Text is then the size the design intended, on any phone.
- **Layout.** Each screen builds into `page`: on phones a vertical scroll page, single column. Helpers decide per layout: `_row` (two columns → stack), `_side`, `_paper`, `_grid` (cards: 1 column under 560 px, 2 under 900), `_flow` (wrapping chips), `_btn_row` (full-width stacked buttons, main action first), `_shrinkable` (buttons sharing a row trim their label with "…" instead of overflowing), `_fs` (big titles shrink, tiny captions grow to ≥ 12 px). Buttons are ≥ 44 px tall.
- **Screens that must not scroll** keep a fixed frame: travel (globe fixed on top, country list scrolls, destination + *Fly* pinned at the bottom; side-by-side in landscape) and the chases (the game gets all the free room, *Start* always visible).
- **Overlays** (clue mini-games, events, cutscenes) fit the screen width (`narrow`: 2×2 transaction grid, stacked receipts, smaller timers) and lower their pictures on short landscape screens (`short`); on phones the overlay layer scrolls if still taller than the screen.
- **Rotation.** A size change that flips phone/desktop or portrait/landscape rebuilds the layout and redraws the current screen — but never during an overlay, flight or chase (their coroutines own those nodes); it waits until they end.
- **Touch.** Godot's scroll containers don't scroll when the finger starts on a button, which on a page of cards is almost everywhere. `main._input` implements drag-to-scroll (with fling) for the innermost scrollable container under the finger; once the finger has moved 12 px, a synthetic pointer move off the held button cancels its press. The interactive globe, chases and sliders keep their drags. The globe gets pinch-to-zoom and +/− buttons (no mouse wheel on phones).

## Verification
`tests/ui_flows.gd -- --phone` (360×740, a small Android phone) and `-- --landscape` (844×390) replay every case and escape through the UI inside a fixed-size viewport. On every screen and every overlay, in both languages, no visible control may extend past the screen edge; a touch test checks that dragging on a button scrolls without pressing it and that a tap presses it. Both run in CI next to the desktop run. `tests/screenshot_tour.gd -- <dir> --phone` renders the tour at any `--resolution`.

## Consequences
- Same build and URL for desktop and phones; Android/iOS exports will reuse the phone layout.
- New screens must build into `page` and use the helpers; the phone flow tests catch overflow automatically.
