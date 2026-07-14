import os, unittest
from argparse import Namespace
import hass

class TestResolveConfig(unittest.TestCase):
    def setUp(self):
        for k in ("HA_URL", "HA_TOKEN"):
            os.environ.pop(k, None)

    def test_flags_win_over_env(self):
        os.environ["HA_URL"] = "http://env:8123"
        os.environ["HA_TOKEN"] = "envtok"
        url, tok = hass.resolve_config(Namespace(url="http://flag:8123/", token="flagtok"))
        self.assertEqual(url, "http://flag:8123")   # trailing slash stripped
        self.assertEqual(tok, "flagtok")

    def test_env_used_when_no_flags(self):
        os.environ["HA_URL"] = "http://env:8123"
        os.environ["HA_TOKEN"] = "envtok"
        url, tok = hass.resolve_config(Namespace(url=None, token=None))
        self.assertEqual((url, tok), ("http://env:8123", "envtok"))

    def test_missing_raises_configerror(self):
        with self.assertRaises(hass.ConfigError):
            hass.resolve_config(Namespace(url=None, token=None))

class TestParseValue(unittest.TestCase):
    def test_bool(self):
        self.assertIs(hass.parse_value("true"), True)
        self.assertIs(hass.parse_value("false"), False)
    def test_int_and_float(self):
        self.assertEqual(hass.parse_value("50"), 50)
        self.assertEqual(hass.parse_value("1.5"), 1.5)
    def test_json_list(self):
        self.assertEqual(hass.parse_value("[255,0,0]"), [255, 0, 0])
    def test_plain_string(self):
        self.assertEqual(hass.parse_value("kitchen"), "kitchen")

class TestIso(unittest.TestCase):
    def test_format_has_t_and_offset(self):
        ts = hass._iso_hours_ago(1)
        self.assertIn("T", ts)
        self.assertTrue(ts.endswith("+00:00") or ts.endswith("Z"))

if __name__ == "__main__":
    unittest.main()
