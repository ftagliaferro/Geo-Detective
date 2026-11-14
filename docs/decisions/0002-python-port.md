# ADR-0002: Engine-independent data + later Python port

- **Status:** Accepted — 2026-11-14

## Context
The owner wants a Python version after the Godot release, as a portfolio piece.

## Decision
- All content (cities, clues, suspects, cases, translations) is stored as JSON in `game/data/`, validated by Python tools in `tools/`.
- Core rules (travel, time cost, clue generation, deduction) are written as plain logic modules with no engine calls, and covered by tests, so they can be ported 1:1.
- The Python port targets **desktop + web demo** (e.g. Pygame), not the app stores; the Godot build remains the commercial product.

## Consequences
Slightly more discipline separating logic from presentation — which is also good architecture.
