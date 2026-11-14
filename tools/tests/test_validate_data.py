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
        d["suspects"]["marcel_dupin"]["traits"]["mark"] = "gold_ring"
        self.assertTrue(any("uniquely" in e for e in vd.validate(d)))

    def test_decoy_on_route_detected(self):
        d = copy.deepcopy(self.data)
        d["cases"]["case_01"]["decoys"][0][0] = "budapest"
        self.assertTrue(any("on the route" in e for e in vd.validate(d)))


if __name__ == "__main__":
    unittest.main()
