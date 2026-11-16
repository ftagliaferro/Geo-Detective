#!/usr/bin/env python3
"""Validate Geo Detective content files (game/data/*.json).

Checks referential integrity, ES/EN completeness and that every case is
solvable: trail clues lead to real cities and the revealed traits single
out the culprit.

Usage:  python3 tools/validate_data.py [data_dir]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

LANGS = ("es", "en")
DEFAULT_DIR = Path(__file__).resolve().parent.parent / "game" / "data"


def load(data_dir: Path) -> dict:
    def read(name: str) -> dict:
        return json.loads((data_dir / name).read_text(encoding="utf-8"))

    return {
        "cities": {c["id"]: c for c in read("cities.json")["cities"]},
        "traits": {t["id"]: t for t in read("traits.json")["traits"]},
        "suspects": {s["id"]: s for s in read("suspects.json")["suspects"]},
        "cases": {c["id"]: c for c in read("cases.json")["cases"]},
        "strings": read("i18n/strings.json")["strings"],
        "escapes": {e["id"]: e for e in read("escapes.json")["escapes"]},
    }


def _i18n(value, where: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{where}: expected {{es, en}} object")
        return
    for lang in LANGS:
        if not str(value.get(lang, "")).strip():
            errors.append(f"{where}: missing '{lang}' text")


def matching(suspects: dict, selection: dict) -> list[str]:
    return sorted(
        sid for sid, s in suspects.items()
        if all(s["traits"].get(t) == v for t, v in selection.items())
    )


def validate(d: dict) -> list[str]:
    errors: list[str] = []
    cities, traits, suspects, cases = d["cities"], d["traits"], d["suspects"], d["cases"]

    for key, val in d["strings"].items():
        _i18n(val, f"strings.{key}", errors)

    for cid, c in cities.items():
        _i18n(c["name"], f"city {cid}.name", errors)
        _i18n(c["country"], f"city {cid}.country", errors)
        if not (-90 <= c["lat"] <= 90 and -180 <= c["lon"] <= 180):
            errors.append(f"city {cid}: invalid coordinates")
        for i, clue in enumerate(c.get("clues", [])):
            _i18n(clue, f"city {cid}.clues[{i}]", errors)
        if c.get("street"):
            _i18n(c["street"]["hint"], f"city {cid}.street.hint", errors)

    for tid, t in traits.items():
        _i18n(t["name"], f"trait {tid}.name", errors)
        for v in t["values"]:
            _i18n(v["label"], f"trait {tid}.{v['id']}.label", errors)
            if not v.get("clues"):
                errors.append(f"trait {tid}.{v['id']}: no clues")
            for i, clue in enumerate(v.get("clues", [])):
                _i18n(clue, f"trait {tid}.{v['id']}.clues[{i}]", errors)

    for sid, s in suspects.items():
        for tid in traits:
            val = s["traits"].get(tid)
            if val not in {v["id"] for v in traits[tid]["values"]}:
                errors.append(f"suspect {sid}: invalid or missing trait {tid}={val!r}")

    if len(cities) < 30:
        errors.append(f"world pool has {len(cities)} cities; need at least 30 for pin-drop landings")

    for kid, k in cases.items():
        _i18n(k["title"], f"case {kid}.title", errors)
        _i18n(k["crime"], f"case {kid}.crime", errors)
        route = k["route"]
        if len(route) < 2:
            errors.append(f"case {kid}: route needs at least 2 cities")
        for city in route:
            if city not in cities:
                errors.append(f"case {kid}: unknown route city {city}")
        tiers = k.get("tiers", [1, 3])
        if not (isinstance(tiers, list) and len(tiers) == 2 and 1 <= tiers[0] <= tiers[1] <= 3):
            errors.append(f"case {kid}: tiers must be [min, max] within 1..3")
            tiers = [1, 3]
        if not isinstance(k.get("cctv_hint_free", True), bool):
            errors.append(f"case {kid}: cctv_hint_free must be true/false")
        for nxt in route[1:]:
            c = cities.get(nxt, {})
            if not c.get("clues"):
                errors.append(f"case {kid}: destination {nxt} has no wiretap clues")
            elif not any(tiers[0] <= cl.get("tier", 1) <= tiers[1] for cl in c["clues"]):
                errors.append(f"case {kid}: destination {nxt} has no clue in tiers {tiers}")
            if not c.get("street"):
                errors.append(f"case {kid}: destination {nxt} has no street look")
        radius = k.get("radius_km")
        if not isinstance(radius, (int, float)) or not 100 <= radius <= 3000:
            errors.append(f"case {kid}: radius_km must be between 100 and 3000")
        culprit = k["culprit"]
        if culprit not in suspects:
            errors.append(f"case {kid}: unknown culprit {culprit}")
            continue
        order = k["trait_order"]
        if sorted(order) != sorted(traits):
            errors.append(f"case {kid}: trait_order must list every trait once")
        # Traits revealed by informants before the final city must single out the culprit.
        revealed = {t: suspects[culprit]["traits"][t] for t in order[: len(route) - 1]}
        group = [sid for sid, s in suspects.items() if s["network"] == k["network"]]
        pool = {sid: suspects[sid] for sid in group}
        if matching(pool, revealed) != [culprit]:
            errors.append(f"case {kid}: trail clues do not uniquely identify {culprit}")
    for eid, e in d.get("escapes", {}).items():
        _i18n(e["title"], f"escape {eid}.title", errors)
        _i18n(e["heist"], f"escape {eid}.heist", errors)
        route = e["route"]
        if len(route) < 3 or len(set(route)) != len(route):
            errors.append(f"escape {eid}: route needs 3+ distinct cities")
        for city in route[1:]:
            c = cities.get(city)
            if not c or not c.get("clues"):
                errors.append(f"escape {eid}: safe house {city} has no clues")
            elif not c.get("country_code"):
                errors.append(f"escape {eid}: {city} has no country_code for the smuggler's map")
        if not 100 <= e.get("radius_km", 0) <= 3000:
            errors.append(f"escape {eid}: radius_km out of range")
        if not (1 <= e.get("head_start", 0) <= 48 and 1 <= e.get("inspector_hours", 0) <= 24):
            errors.append(f"escape {eid}: head_start / inspector_hours out of range")
    return errors


def photo_warnings(d: dict) -> list[str]:
    """Route cities without a CCTV photo (allowed, but worth knowing)."""
    used = {c for k in d["cases"].values() for c in k["route"][1:]}
    used |= {c for e in d.get("escapes", {}).values() for c in e["route"][1:]}
    return sorted(c for c in used if not ((d["cities"].get(c, {}).get("street") or {}).get("image")))


def main(argv: list[str]) -> int:
    data_dir = Path(argv[1]) if len(argv) > 1 else DEFAULT_DIR
    d = load(data_dir)
    missing = photo_warnings(d)
    if missing:
        print(f"WARNING: {len(missing)} destination(s) without street photo: {', '.join(missing)}")
    errors = validate(d)
    for e in errors:
        print("ERROR:", e)
    print(f"{'OK' if not errors else 'FAILED'} — {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
