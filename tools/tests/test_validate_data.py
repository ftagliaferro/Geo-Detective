import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import validate_data as vd  # noqa: E402


class ValidateDataTest(unittest.TestCase):
    def setUp(self):
        self.data = vd.load(vd.DEFAULT_DIR)

    def test_shipped_data_is_valid(self):
        self.assertEqual(vd.validate(self.data), [])

    def test_missing_translation_detected(self):
        d = copy.deepcopy(self.data)
        d["cities"]["lisbon"]["name"]["en"] = ""
        self.assertTrue(any("lisbon.name" in e for e in vd.validate(d)))

    def test_unknown_route_city_detected(self):
        d = copy.deepcopy(self.data)
        d["cases"]["case_01"]["route"][1] = "atlantis"
        self.assertTrue(any("atlantis" in e for e in vd.validate(d)))

    def test_ambiguous_culprit_detected(self):
        d = copy.deepcopy(self.data)
        case = d["cases"]["case_01"]
        culprit = d["suspects"][case["culprit"]]
        for sid, s in d["suspects"].items():
            if s["network"] == case["network"]:
                s["traits"] = dict(culprit["traits"])
        self.assertTrue(any("uniquely" in e for e in vd.validate(d)))

    def test_bad_radius_detected(self):
        d = copy.deepcopy(self.data)
        d["cases"]["case_01"]["radius_km"] = 10
        self.assertTrue(any("radius_km" in e for e in vd.validate(d)))


if __name__ == "__main__":
    unittest.main()


class TierTest(unittest.TestCase):
    def test_bad_tiers_detected(self):
        d = copy.deepcopy(vd.load(vd.DEFAULT_DIR))
        d["cases"]["case_02"]["tiers"] = [3, 1]
        self.assertTrue(any("tiers" in e for e in vd.validate(d)))


class EscapeTest(unittest.TestCase):
    def test_escape_without_clues_detected(self):
        d = copy.deepcopy(vd.load(vd.DEFAULT_DIR))
        d["escapes"]["escape_01"]["route"][1] = "tokyo_missing"
        d["cities"]["tokyo_missing"] = {"id": "tokyo_missing", "name": {"es": "x", "en": "x"}, "country": {"es": "x", "en": "x"}, "lat": 0, "lon": 0, "clues": []}
        self.assertTrue(any("no clues" in e for e in vd.validate(d)))


class ValidateDepthTest(unittest.TestCase):
    """ADR-0015 content checks."""

    def setUp(self):
        self.data = vd.load(vd.DEFAULT_DIR)

    def test_shipped_depth_data_is_valid(self):
        self.assertEqual(vd.validate_depth(self.data), [])

    def test_missing_country_facts_detected(self):
        d = copy.deepcopy(self.data)
        del d["facts"]["countries"]["PRT"]
        self.assertTrue(any("PRT" in e for e in vd.validate_depth(d)))

    def test_bad_event_effect_detected(self):
        d = copy.deepcopy(self.data)
        d["events"]["events"][0]["options"][0]["effects"].append(["teleport"])
        self.assertTrue(any("bad effect" in e for e in vd.validate_depth(d)))

    def test_unknown_speaker_detected(self):
        d = copy.deepcopy(self.data)
        d["story"]["scenes"]["case_01"]["intro"][0]["who"] = "nobody"
        self.assertTrue(any("unknown speaker" in e for e in vd.validate_depth(d)))

    def test_split_thieves_must_share_early_traits(self):
        d = copy.deepcopy(self.data)
        case = d["cases"]["case_07"]
        t = case["trait_order"][0]
        b = d["suspects"][case["culprit_b"]]["traits"]
        values = [v["id"] for v in d["traits"][t]["values"]]
        b[t] = next(v for v in values if v != b[t])
        self.assertTrue(any("share the traits" in e for e in vd.validate_depth(d)))

    def test_city_without_map_data_detected(self):
        d = copy.deepcopy(self.data)
        d["cities"]["lisbon"]["water"] = "lava"
        self.assertTrue(any("lisbon" in e for e in vd.validate_depth(d)))
