# ADR-0001: Use Godot 4 as the game engine

- **Status:** Accepted — 2026-11-14

## Context
The game must ship on PC, Android, iOS and Web from a single codebase, with stylized 3D graphics, ads and in-app purchases. The developer's PC is low-end and there is no Mac available.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Python (Pygame/Panda3D/Kivy) | Familiar language | No reliable path to App Store / Play Store; weak mobile ads/IAP support |
| Unity | Mature, mobile ecosystem | Heavy editor for a low-end PC; licensing changes |
| **Godot 4** | Free & open source (MIT), lightweight editor, exports to all 4 targets, GDScript is Python-like, AdMob/IAP plugins | Smaller ecosystem than Unity |

## Decision
Godot 4 with GDScript. Use the *Compatibility* renderer so it runs on modest hardware and in browsers.

## Consequences
- iOS builds require macOS → use GitHub Actions macOS runners (free for public repos) instead of owning a Mac.
- Game data (cases, cities, clues) lives in plain JSON so it is engine-independent (see ADR-0002).
