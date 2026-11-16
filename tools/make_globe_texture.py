#!/usr/bin/env python3
"""Render the stylized equirectangular world texture used by the 3D globe.

Source: Natural Earth 1:110m countries (public domain), fetched once and cached.
Style: modern flat map — soft sky-blue ocean, warm white land, light taupe borders.

Usage:  python3 tools/make_globe_texture.py [--size 2048]
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache" / "ne_110m_admin_0_countries.geojson"
OUT = ROOT / "game" / "assets" / "globe" / "world.png"
SOURCE = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
          "master/geojson/ne_110m_admin_0_countries.geojson")

OCEAN = (143, 196, 232)
GRID = (164, 210, 240)
LAND = (251, 247, 239)
COAST = (176, 163, 140)


def load_geojson() -> dict:
    if not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(SOURCE, CACHE)
    return json.loads(CACHE.read_text(encoding="utf-8"))


def project(lon: float, lat: float, w: int, h: int) -> tuple[float, float]:
    return (lon + 180.0) / 360.0 * w, (90.0 - lat) / 180.0 * h


def rings(geometry: dict):
    if geometry["type"] == "Polygon":
        yield from geometry["coordinates"][:1]
    elif geometry["type"] == "MultiPolygon":
        for poly in geometry["coordinates"]:
            yield poly[0]


def render(size: int) -> Image.Image:
    w, h = size, size // 2
    img = Image.new("RGB", (w, h), OCEAN)
    d = ImageDraw.Draw(img)
    for lon in range(-180, 181, 30):
        x, _ = project(lon, 0, w, h)
        d.line([(x, 0), (x, h)], fill=GRID, width=1)
    for lat in range(-60, 61, 30):
        _, y = project(0, lat, w, h)
        d.line([(0, y), (w, y)], fill=GRID, width=1)

    polys = [[project(lon, lat, w, h) for lon, lat in ring]
             for f in load_geojson()["features"] for ring in rings(f["geometry"])]
    for pts in polys:
        d.polygon(pts, fill=LAND)
    for pts in polys:
        d.line(pts + [pts[0]], fill=COAST, width=max(1, size // 1400))
    return img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=2048)
    args = ap.parse_args()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    render(args.size).save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
