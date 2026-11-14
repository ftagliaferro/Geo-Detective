#!/usr/bin/env python3
"""Build game/data/countries.json (names ES/EN, label position, label rank) from
Natural Earth 1:110m (public domain) and tag every city with its country code.

Usage:  python3 tools/make_countries.py   (run make_globe_texture.py first to cache the data)
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / ".cache" / "ne_110m_admin_0_countries.geojson"
DATA = ROOT / "game" / "data"
ALIASES = {"United States": "United States of America", "Türkiye": "Turkey", "China": "People's Republic of China"}
DISPLAY = {"CHN": {"en": "China"}, "USA": {"en": "United States"}, "TUR": {"en": "Türkiye"}}
EXTRA = [  # too small for the 1:110m dataset
    {"id": "SGP", "name": {"es": "Singapur", "en": "Singapore"}, "lat": 1.35, "lon": 103.82, "rank": 4},
]


def main() -> None:
    feats = json.loads(SRC.read_text(encoding="utf-8"))["features"]
    countries, by_en = [], {}
    for f in feats:
        p = f["properties"]
        if p["ADM0_A3"] in ("ATA",):  # Antarctica: no label needed
            continue
        c = {"id": p["ADM0_A3"], "name": {"es": p["NAME_ES"], "en": p["NAME_EN"]},
             "lat": round(p["LABEL_Y"], 3), "lon": round(p["LABEL_X"], 3), "rank": int(p["LABELRANK"])}
        c["name"].update(DISPLAY.get(c["id"], {}))
        countries.append(c)
        by_en[p["NAME_EN"]] = c["id"]
    countries += EXTRA
    by_en["Singapore"] = "SGP"
    countries.sort(key=lambda c: c["id"])
    rows = ",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in countries)
    (DATA / "countries.json").write_text('{\n  "countries": [\n' + rows + "\n  ]\n}\n", encoding="utf-8")

    cities = json.loads((DATA / "cities.json").read_text(encoding="utf-8"))
    for c in cities["cities"]:
        en = c["country"]["en"]
        c["country_code"] = by_en[ALIASES.get(en, en)]
    rows = ",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in cities["cities"])
    (DATA / "cities.json").write_text('{\n  "cities": [\n' + rows + "\n  ]\n}\n", encoding="utf-8")
    print(f"{len(countries)} countries; tagged {len(cities['cities'])} cities")


if __name__ == "__main__":
    main()
