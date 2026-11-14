#!/usr/bin/env python3
"""Build the campaign JSON (traits, suspects, cases, city clues) from campaign_content.py.

Suspect traits are assigned with a seeded search so that, for every case, the
traits revealed on the trail single out the culprit only at the last hop
before the final city (fair but not trivial). Re-running is deterministic.

Usage:  python3 tools/generate_campaign.py
"""
from __future__ import annotations

import itertools
import math
import json
import random
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from campaign_content import CASES, CLUES, ESCAPES, NETWORKS, TRAIT_VALUES  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / "game" / "data"
TRAITS = list(TRAIT_VALUES)


def slug(name: str) -> str:
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    keep = "".join(ch.lower() if ch.isalnum() else "_" for ch in name.replace('"', ""))
    return "_".join(p for p in keep.split("_") if p)


def matching(pool: dict, sel: dict) -> list:
    return [sid for sid, tr in pool.items() if all(tr[t] == v for t, v in sel.items())]


def case_ok(pool: dict, culprit: str, order: list, k: int) -> bool:
    sel = {t: pool[culprit][t] for t in order[:k]}
    if matching(pool, sel) != [culprit]:
        return False
    if k >= 2:  # must still be ambiguous one hop earlier
        prev = {t: pool[culprit][t] for t in order[: k - 1]}
        if len(matching(pool, prev)) < 2:
            return False
    return True


def build_network(net_id: str, cases: list, rng: random.Random):
    names = NETWORKS[net_id]["suspects"]
    ids = [slug(n) for n in names]
    culprits = [ids[1], ids[2], ids[0]]  # third case = network boss
    values = {t: [v[0] for v in TRAIT_VALUES[t][2]] for t in TRAITS}
    for _ in range(200000):
        pool = {sid: {t: rng.choice(values[t]) for t in TRAITS} for sid in ids}
        if len({tuple(tr.values()) for tr in pool.values()}) < len(ids):
            continue
        orders = []
        for case, culprit in zip(cases, culprits):
            k = min(len(case[2]) - 1, len(TRAITS))
            found = None
            perms = list(itertools.permutations(TRAITS))
            rng.shuffle(perms)
            for order in perms[:60]:
                if case_ok(pool, culprit, list(order), k):
                    found = list(order)
                    break
            if not found:
                break
            orders.append(found)
        else:
            return names, ids, pool, culprits, orders
    raise RuntimeError(f"could not build network {net_id}")


SLACK = {"paper_saints": 2.2, "blue_harbour": 1.8, "zero_signal": 1.6, "velvet_hands": 1.45, "glass_serpent": 1.35}


def km(a: dict, b: dict) -> float:
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dp, dl = p2 - p1, math.radians(b["lon"] - a["lon"])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371 * math.asin(math.sqrt(h))


def time_budget(route: list, cities: dict, net_id: str, free_hint: bool) -> int:
    """Perfect run (all evidence + exact flights + CCTV analysis) times the arc's slack."""
    flights = sum(2 + round(km(cities[a], cities[b]) / 800) for a, b in zip(route, route[1:]))
    evidence = 9 * len(route) + (0 if free_hint else len(route) - 1)  # 2+2+3+2 h per city
    return int(math.ceil((flights + evidence) * SLACK[net_id] / 5.0) * 5)


def main() -> None:
    rng = random.Random(20261114)
    traits_json = {"traits": [
        {"id": t, "name": {"es": es, "en": en}, "values": [
            {"id": vid, "label": {"es": les, "en": len_}, "clues": [{"es": ces, "en": cen}]}
            for vid, les, len_, ces, cen in vals]}
        for t, (es, en, vals) in TRAIT_VALUES.items()]}

    cities = json.loads((DATA / "cities.json").read_text(encoding="utf-8"))
    city_by_id = {c["id"]: c for c in cities["cities"]}
    suspects, cases_out = [], []
    for net_id in NETWORKS:
        net_cases = [c for c in CASES if c[1] == net_id]
        names, ids, pool, culprits, orders = build_network(net_id, net_cases, rng)
        for name, sid in zip(names, ids):
            suspects.append({"id": sid, "name": name, "network": net_id, "traits": pool[sid]})
        for case, culprit, order in zip(net_cases, culprits, orders):
            num, _, route, tiers, radius, hours, free, title, crime = case
            cases_out.append({
                "id": f"case_{num:02d}", "number": num, "network": net_id,
                "network_name": {"es": NETWORKS[net_id]["name"][0], "en": NETWORKS[net_id]["name"][1]},
                "title": {"es": f"Caso {num}: {title[0]}", "en": f"Case {num}: {title[1]}"},
                "crime": {"es": crime[0], "en": crime[1]},
                "hours": time_budget(route, city_by_id, net_id, free), "radius_km": radius, "tiers": list(tiers), "cctv_hint_free": free,
                "route": route, "culprit": culprit, "trait_order": order,
            })
    cases_out.sort(key=lambda c: c["number"])

    for c in cities["cities"]:
        if c["id"] in CLUES:
            t1, t2, t3, hint = CLUES[c["id"]]
            c["clues"] = [{"tier": i + 1, "es": es, "en": en} for i, (es, en) in enumerate((t1, t2, t3))]
            street = c.get("street") or {}
            street["hint"] = {"es": hint[0], "en": hint[1]}
            street.setdefault("image", None)
            c["street"] = street
    rows = ",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in cities["cities"])
    (DATA / "cities.json").write_text('{\n  "cities": [\n' + rows + "\n  ]\n}\n", encoding="utf-8")
    (DATA / "traits.json").write_text(json.dumps(traits_json, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DATA / "suspects.json").write_text(json.dumps({"suspects": suspects}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DATA / "cases.json").write_text(json.dumps({"cases": cases_out}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    escapes = [{
        "id": f"escape_{num:02d}", "number": num, "network": net,
        "network_name": {"es": NETWORKS[net]["name"][0], "en": NETWORKS[net]["name"][1]},
        "title": {"es": f"Fuga {num}: {title[0]}", "en": f"Escape {num}: {title[1]}"},
        "heist": {"es": heist[0], "en": heist[1]},
        "route": route, "tiers": list(tiers), "radius_km": radius,
        "head_start": lag, "inspector_hours": inv,
    } for num, net, route, tiers, radius, lag, inv, title, heist in ESCAPES]
    (DATA / "escapes.json").write_text(json.dumps({"escapes": escapes}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(escapes)} escapes")
    print(f"{len(cases_out)} cases, {len(suspects)} suspects, {sum(1 for c in cities['cities'] if c['id'] in CLUES)} cities with clues")


if __name__ == "__main__":
    main()
