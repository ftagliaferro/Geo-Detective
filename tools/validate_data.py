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

    for kid, k in cases.items():
        _i18n(k["title"], f"case {kid}.title", errors)
        _i18n(k["crime"], f"case {kid}.crime", errors)
        route = k["route"]
        if len(route) < 2:
            errors.append(f"case {kid}: route needs at least 2 cities")
        for city in route:
            if city not in cities:
                errors.append(f"case {kid}: unknown route city {city}")
        for nxt in route[1:]:
            c = cities.get(nxt, {})
            if not c.get("clues"):
                errors.append(f"case {kid}: destination {nxt} has no witness clues")
            if not c.get("street"):
                errors.append(f"case {kid}: destination {nxt} has no street look")
        if len(k["decoys"]) != len(route) - 1:
            errors.append(f"case {kid}: need one decoy list per hop")
        for i, decoys in enumerate(k["decoys"]):
            if len(decoys) != 3:
                errors.append(f"case {kid}: hop {i} needs exactly 3 decoys")
            for dc in decoys:
                if dc not in cities:
                    errors.append(f"case {kid}: unknown decoy {dc}")
                if dc in route:
                    errors.append(f"case {kid}: decoy {dc} is on the route")
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
    return errors


def main(argv: list[str]) -> int:
    data_dir = Path(argv[1]) if len(argv) > 1 else DEFAULT_DIR
    errors = validate(load(data_dir))
    for e in errors:
        print("ERROR:", e)
    print(f"{'OK' if not errors else 'FAILED'} — {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
