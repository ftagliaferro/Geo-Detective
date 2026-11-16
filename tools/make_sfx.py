#!/usr/bin/env python3
"""Synthesize the game's sound effects (original, no third-party audio).

Writes 16-bit mono WAVs to game/assets/sfx/. Pure standard library.
Usage:  python3 tools/make_sfx.py
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "sfx"
rng = random.Random(7)


def env(i: int, n: int, attack: float = 0.01, release: float = 0.5) -> float:
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (1.0 - t) / release) if release > 0 else 1.0
    return a * r


def tone(freq: float, dur: float, kind: str = "sine", vol: float = 0.5, attack=0.01, release=0.6, slide: float = 0.0) -> list[float]:
    n = int(RATE * dur)
    out, ph = [], 0.0
    for i in range(n):
        f = freq + slide * (i / n)
        ph += 2 * math.pi * f / RATE
        if kind == "sine":
            s = math.sin(ph)
        elif kind == "tri":
            s = 2 / math.pi * math.asin(math.sin(ph))
        else:  # soft square
            s = math.tanh(3 * math.sin(ph))
        out.append(s * vol * env(i, n, attack, release))
    return out


def noise(dur: float, vol: float = 0.4, smooth: int = 1, attack=0.01, release=0.7) -> list[float]:
    n = int(RATE * dur)
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    out, acc = [], 0.0
    for i, x in enumerate(raw):
        acc += (x - acc) / smooth
        out.append(acc * vol * env(i, n, attack, release))
    return out


def mix(*tracks: list[float], offsets: list[float] | None = None) -> list[float]:
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        start = int(o * RATE)
        for i, s in enumerate(t):
            out[start + i] += s
    return out


def save(name: str, samples: list[float]) -> None:
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save("click", mix(tone(1400, 0.035, "sine", 0.5, 0.002, 0.9), noise(0.01, 0.2, 1, 0.001, 0.9)))
    save("tick", tone(2200, 0.012, "sine", 0.25, 0.001, 0.9))
    save("pop", tone(520, 0.09, "sine", 0.6, 0.005, 0.8, slide=420))
    save("static", noise(0.9, 0.35, 2, 0.05, 0.3))
    save("lock", mix(tone(880, 0.09, "tri", 0.5), tone(1320, 0.16, "tri", 0.5), offsets=[0, 0.09]))
    save("shutter", mix(noise(0.03, 0.8, 1, 0.001, 0.9), noise(0.05, 0.6, 2, 0.001, 0.9), offsets=[0, 0.07]))
    save("coin", mix(tone(1760, 0.12, "sine", 0.45, 0.002, 0.8), tone(2349, 0.25, "sine", 0.45, 0.002, 0.8), offsets=[0, 0.07]))
    save("whoosh", noise(0.9, 0.7, 6, 0.45, 0.5))
    save("plane", mix(noise(1.8, 0.5, 9, 0.3, 0.6), tone(110, 1.8, "tri", 0.18, 0.3, 0.6, slide=60)))
    save("siren", mix(*[tone(700 if k % 2 == 0 else 950, 0.32, "square", 0.22, 0.02, 0.1) for k in range(4)], offsets=[k * 0.32 for k in range(4)]))
    save("stamp", mix(tone(90, 0.18, "sine", 0.9, 0.002, 0.9), noise(0.06, 0.5, 2, 0.001, 0.9)))
    save("success", mix(*[tone(f, 0.22, "tri", 0.4, 0.005, 0.7) for f in (523, 659, 784, 1047)], offsets=[0, 0.1, 0.2, 0.3]))
    save("fail", mix(tone(392, 0.25, "tri", 0.45), tone(311, 0.45, "tri", 0.45), offsets=[0, 0.22]))
    save("hit", mix(noise(0.08, 0.7, 2, 0.001, 0.9), tone(160, 0.12, "sine", 0.6, 0.001, 0.9)))
    save("alert", mix(tone(988, 0.12, "square", 0.25), tone(988, 0.12, "square", 0.25), offsets=[0, 0.18]))
    print("wrote", len(list(OUT.glob("*.wav"))), "sounds")


if __name__ == "__main__":
    main()
