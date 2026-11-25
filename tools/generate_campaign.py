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
import depth_content as depth  # noqa: E402

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


def split_route_b(case) -> list:
    """Full route of the short branch of a two-thieves case (shared prefix + branch)."""
    at, tail = depth.SPLITS[case[0]]
    return case[2][: at + 1] + tail


def build_network(net_id: str, cases: list, rng: random.Random):
    """Suspect traits + per-case trait orders. Two-thieves cases also get a second
    culprit who shares every trait revealed before the split and is singled out by
    their own branch (ADR-0015 §6)."""
    names = NETWORKS[net_id]["suspects"]
    ids = [slug(n) for n in names]
    culprits = [ids[1], ids[2], ids[0]]  # third case = network boss
    values = {t: [v[0] for v in TRAIT_VALUES[t][2]] for t in TRAITS}
    perms = list(itertools.permutations(TRAITS))
    for _ in range(200000):
        pool = {sid: {t: rng.choice(values[t]) for t in TRAITS} for sid in ids}
        if len({tuple(tr.values()) for tr in pool.values()}) < len(ids):
            continue
        orders, seconds = [], []
        for case, culprit in zip(cases, culprits):
            k = min(len(case[2]) - 1, len(TRAITS))
            found, second = None, None
            rng.shuffle(perms)
            for order in perms[:60]:
                order = list(order)
                if not case_ok(pool, culprit, order, k):
                    continue
                if case[0] not in depth.SPLITS:
                    found = order
                    break
                at = depth.SPLITS[case[0]][0]
                m = at + 1   # traits revealed on the shared stretch (stops 0..split)
                kb = min(len(split_route_b(case)) - 1, len(TRAITS))
                for b in ids:
                    if b in culprits or any(pool[b][t] != pool[culprit][t] for t in order[:m]):
                        continue
                    for rest in itertools.permutations(order[m:]):
                        order_b = order[:m] + list(rest)
                        if case_ok(pool, b, order_b, kb):
                            second = (b, order_b)
                            break
                    if second:
                        break
                if second:
                    found = order
                    break
            if not found:
                break
            orders.append(found)
            seconds.append(second)
        else:
            return names, ids, pool, culprits, orders, seconds
    raise RuntimeError(f"could not build network {net_id}")


SLACK = {"paper_saints": 2.2, "blue_harbour": 1.8, "zero_signal": 1.6, "velvet_hands": 1.45, "glass_serpent": 1.35}


def km(a: dict, b: dict) -> float:
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dp, dl = p2 - p1, math.radians(b["lon"] - a["lon"])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371 * math.asin(math.sqrt(h))


# Mirrors core/case_state.gd (ADR-0015 §1): two text sources get two tiers of the
# case band; clear clues cost more.
TIER_COST = {1: 3, 2: 2, 3: 1}
MONEY_COST = 2
LEAD0 = {"paper_saints": 11, "blue_harbour": 11, "zero_signal": 10, "velvet_hands": 10, "glass_serpent": 9}


def source_tiers(band) -> tuple:
    lo, hi = int(band[0]), int(band[1])
    if lo != hi:
        return (lo, hi)
    return (lo, lo + 1) if lo < 3 else (lo, lo - 1)


# Room for wrong flights, in worst-case round trips (generous while learning).
MISTAKES = {"paper_saints": 3.2, "blue_harbour": 1.8, "zero_signal": 1.8, "velvet_hands": 1.2, "glass_serpent": 1.0}
PAR_SLACK = {"paper_saints": 1.5, "blue_harbour": 1.4, "zero_signal": 1.3, "velvet_hands": 1.25, "glass_serpent": 1.2}


def time_budget(route: list, cities: dict, net_id: str, band, objective: str) -> int:
    """Par run (the clearest where-clue + the money trail + 1 h spare per trail city,
    exact flights, the finale) times the arc's slack, plus room for wrong flights
    (a worst-case round trip ≈ twice the longest leg)."""
    legs = [2 + round(km(cities[a], cities[b]) / 800) for a, b in zip(route, route[1:])]
    where = TIER_COST[min(source_tiers(band))]
    trail = (len(route) - 1) * (where + MONEY_COST + 1)
    finale = 5 if objective == "recover" else 4
    par = (sum(legs) + trail + finale) * PAR_SLACK[net_id]
    room = MISTAKES[net_id] * 2 * max(legs + [12])   # decoys can be far even on short routes
    return int(math.ceil((par + room) / 5.0) * 5)


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
        names, ids, pool, culprits, orders, seconds = build_network(net_id, net_cases, rng)
        for name, sid in zip(names, ids):
            suspects.append({"id": sid, "name": name, "network": net_id, "traits": pool[sid]})
        for pos, (case, culprit, order, second) in enumerate(zip(net_cases, culprits, orders, seconds)):
            num, _, route, tiers, radius, hours, free, title, crime = case
            crime = depth.CRIME_OVERRIDES.get(num, crime)
            objective = depth.OBJECTIVES.get(num, "pursuit")
            longest = route
            if num in depth.SPLITS and len(split_route_b(case)) > len(route):
                longest = split_route_b(case)
            out = {
                "id": f"case_{num:02d}", "number": num, "network": net_id,
                "network_name": {"es": NETWORKS[net_id]["name"][0], "en": NETWORKS[net_id]["name"][1]},
                "title": {"es": f"Caso {num}: {title[0]}", "en": f"Case {num}: {title[1]}"},
                "crime": {"es": crime[0], "en": crime[1]},
                "hours": time_budget(longest, city_by_id, net_id, tiers, objective), "radius_km": radius, "tiers": list(tiers), "cctv_hint_free": free,
                "route": route, "culprit": culprit, "trait_order": order,
                "objective": objective, "lead0": LEAD0[net_id],
                "twists": 0 if num == 1 else (pos if net_id == "paper_saints" else pos + 1),
            }
            if second:
                out["split_at"] = depth.SPLITS[num][0]
                out["route_b"] = depth.SPLITS[num][1]
                out["culprit_b"], out["trait_order_b"] = second
            cases_out.append(out)
    cases_out.sort(key=lambda c: c["number"])

    for c in cities["cities"]:
        if c["id"] in CLUES:
            t1, t2, t3, hint = CLUES[c["id"]]
            c["clues"] = [{"tier": i + 1, "es": es, "en": en} for i, (es, en) in enumerate((t1, t2, t3))]
            street = c.get("street") or {}
            street["hint"] = {"es": hint[0], "en": hint[1]}
            street.setdefault("image", None)
            c["street"] = street
        if c["id"] in depth.CITY_MAP:
            les, len_, water = depth.CITY_MAP[c["id"]]
            c["landmark"] = {"es": les, "en": len_}
            c["water"] = water
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
    write_depth_data()
    print(f"{len(cases_out)} cases, {len(suspects)} suspects, {sum(1 for c in cities['cities'] if c['id'] in CLUES)} cities with clues")


def i18n(pair) -> dict:
    return {"es": pair[0], "en": pair[1]}


def card(e: dict) -> dict:
    return {"id": e["id"], "needs": e.get("needs", []), "title": i18n(e["title"]), "text": i18n(e["text"]),
            "options": [{"label": i18n(o["label"]), "effects": o["effects"]} for o in e["options"]]}


def write_depth_data() -> None:
    """facts.json, hideout.json, events.json, story.json (ADR-0015)."""
    facts = {
        "categories": depth.FACT_CATEGORIES,
        "values": {cat: {v: i18n(lbl) for v, lbl in vals.items()} for cat, vals in depth.FACT_VALUES.items()},
        "texts": {cat: i18n(t) for cat, t in depth.FACT_TEXT.items()},
        "countries": {code: dict(zip(depth.FACT_CATEGORIES, vals)) for code, vals in depth.FACTS.items()},
    }
    hideout = {
        "attrs": depth.HIDEOUT_ATTRS,
        "values": {a: {v: {"label": i18n(lbl), "hint": i18n(h)} for v, (lbl, h) in vals.items()} for a, vals in depth.HIDEOUT_VALUES.items()},
        "names": [{"kind": k, "zone": z, "name": i18n(n)} for (k, z), n in depth.HIDEOUT_NAMES.items()],
    }
    events = {"events": [card(e) for e in depth.EVENTS], "reactions": [card(e) for e in depth.REACTIONS]}
    story = {
        "characters": {k: i18n(v) for k, v in depth.CHARACTERS.items()},
        "looks": depth.CHARACTER_LOOKS,
        "scenes": {f"case_{n:02d}": {part: [{"who": sp, "es": es, "en": en} for sp, es, en in lines]
                                     for part, lines in sc.items()} for n, sc in depth.STORY.items()},
        "gang_files": {k: i18n(v) for k, v in depth.GANG_FILES.items()},
        "gang_twist": depth.GANG_TWIST,
        "messages": {k: [i18n(m) for m in v] for k, v in depth.MESSAGES.items()},
    }
    for name, obj in (("facts", facts), ("hideout", hideout), ("events", events), ("story", story)):
        (DATA / f"{name}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("depth data: facts, hideout, events, story")


if __name__ == "__main__":
    main()
