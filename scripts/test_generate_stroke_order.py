import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from generate_stroke_order import build_catalog, convert_record, parse_svg_path


class StrokeOrderGeneratorTests(unittest.TestCase):
    def test_flips_source_coordinates_and_keeps_path_commands(self):
        commands = parse_svg_path("M 0 900 L 1024 -124 Q 512 388 512 900 Z")

        self.assertEqual(
            commands,
            [
                ["M", 0, 0],
                ["L", 1024, 1024],
                ["Q", 512, 512, 512, 0],
                ["Z"],
            ],
        )

    def test_rejects_unclosed_path(self):
        with self.assertRaises(ValueError):
            parse_svg_path("M 0 900 L 1024 -124")

    def test_rejects_unknown_svg_commands(self):
        with self.assertRaisesRegex(ValueError, "Unsupported SVG command"):
            parse_svg_path("M 0 900 R 10 890 Z")

    def test_converts_strokes_in_source_order(self):
        record = convert_record(
            {
                "character": "好",
                "strokes": ["M 0 900 L 10 890 Z", "M 10 890 L 20 880 Z"],
                "medians": [[[0, 900], [10, 890]], [[10, 890], [20, 880]]],
            }
        )

        self.assertEqual(len(record["strokes"]), 2)
        self.assertEqual(record["strokes"][0]["median"], [[0, 0], [10, 10]])
        self.assertEqual(record["strokes"][1]["path"][0], ["M", 10, 10])

    def test_catalog_fails_when_a_required_character_is_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "hsk1.json").write_text(
                json.dumps([{"simplified": "好"}]), encoding="utf-8"
            )
            for level in range(2, 8):
                (root / f"hsk{level}.json").write_text("[]", encoding="utf-8")
            source = root / "graphics.txt"
            source.write_text(
                json.dumps(
                    {
                        "character": "你",
                        "strokes": ["M 0 900 L 10 890 Z"],
                        "medians": [[[0, 900], [10, 890]]],
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "missing stroke data"):
                build_catalog(source, root)


if __name__ == "__main__":
    unittest.main()
