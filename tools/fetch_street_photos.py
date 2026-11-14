#!/usr/bin/env python3
"""Download curated CCTV/street photos from Wikimedia Commons and record credits.

Each city with a `street.source` (a Commons file title) gets:
  - game/assets/street/<city_id>.jpg  (960 px wide thumbnail)
  - street.image  = res:// path
  - street.credit = {artist, license, url}
and CREDITS.md is regenerated. Only free licenses are accepted (ADR-0003, ADR-0005).

Usage:  python3 tools/fetch_street_photos.py [--force]
"""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "game" / "data" / "cities.json"
OUT_DIR = ROOT / "game" / "assets" / "street"
CREDITS = ROOT / "CREDITS.md"
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "EduGameAssetCuration/0.1 (open-license image curation; low volume)"}
ALLOWED = ("CC0", "Public domain", "CC BY 2.0", "CC BY 3.0", "CC BY 4.0",
           "CC BY-SA 2.0", "CC BY-SA 3.0", "CC BY-SA 4.0")


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=60).read()


def file_info(title: str) -> dict:
    params = {"action": "query", "format": "json", "titles": title, "prop": "imageinfo",
              "iiprop": "url|extmetadata", "iiurlwidth": 960}
    data = json.loads(_get(API + "?" + urllib.parse.urlencode(params)))
    page = next(iter(data["query"]["pages"].values()))
    ii = page["imageinfo"][0]
    meta = ii.get("extmetadata", {})
    artist = re.sub(r"<[^>]+>", "", meta.get("Artist", {}).get("value", "Unknown")).strip()
    return {"thumb": ii["thumburl"], "url": ii["descriptionurl"],
            "license": meta.get("LicenseShortName", {}).get("value", "?"), "artist": artist}


def write_cities(doc: dict) -> None:
    rows = ",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in doc["cities"])
    CITIES.write_text('{\n  "cities": [\n' + rows + "\n  ]\n}\n", encoding="utf-8")


def write_credits(doc: dict) -> None:
    lines = ["# Credits", "", "## Map data",
             "- World borders: [Natural Earth](https://www.naturalearthdata.com/) 1:110m — public domain.", "",
             "## Street / CCTV photos (Wikimedia Commons)", ""]
    for c in doc["cities"]:
        cr = (c.get("street") or {}).get("credit")
        if cr:
            lines.append(f"- **{c['name']['en']}** — {cr['artist']} · {cr['license']} · <{cr['url']}>")
    lines += ["", "## Engine", "- [Godot Engine](https://godotengine.org) — MIT license.", ""]
    CREDITS.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    doc = json.loads(CITIES.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for c in doc["cities"]:
        st = c.get("street") or {}
        if not st.get("source"):
            continue
        dest = OUT_DIR / f"{c['id']}.jpg"
        if dest.exists() and st.get("credit") and not args.force:
            continue
        info = file_info(st["source"])
        if not info["license"].startswith(ALLOWED):
            print(f"SKIP {c['id']}: license {info['license']!r} not allowed")
            continue
        dest.write_bytes(_get(info["thumb"]))
        st["image"] = f"res://assets/street/{c['id']}.jpg"
        st["credit"] = {"artist": info["artist"], "license": info["license"], "url": info["url"]}
        print(f"ok {c['id']}: {info['license']} — {info['artist']}")
        time.sleep(5)
    write_cities(doc)
    write_credits(doc)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
