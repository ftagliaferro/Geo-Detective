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
