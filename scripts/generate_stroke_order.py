#!/usr/bin/env python3
"""Build the native stroke-order catalog from Make Me a Hanzi graphics data."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


TOKEN_RE = re.compile(r"[A-Za-z]|-?(?:\d+(?:\.\d*)?|\.\d+)")
COMMAND_ARITY = {"M": 2, "L": 2, "Q": 4, "C": 6}


def is_hanzi(character: str) -> bool:
    return any(
        0x3400 <= codepoint <= 0x4DBF
        or 0x4E00 <= codepoint <= 0x9FFF
        or 0x20000 <= codepoint <= 0x2A6DF
        for codepoint in (ord(character),)
    )


def normalized_number(value: float) -> int | float:
    return int(value) if value.is_integer() else value


def normalized_point(x: float, y: float) -> list[int | float]:
    # Make Me a Hanzi uses a flipped 1024x1024 coordinate system with its
    # top edge at y=900. Native drawing uses the usual top-left origin.
    return [normalized_number(x), normalized_number(900 - y)]


def parse_svg_path(path_data: str) -> list[list[Any]]:
    tokens = TOKEN_RE.findall(path_data)
    if not tokens:
        raise ValueError("SVG path is empty")

    commands: list[list[Any]] = []
    index = 0
    command: str | None = None

    while index < len(tokens):
        token = tokens[index]
        if token.isalpha():
            if token not in COMMAND_ARITY and token != "Z":
                raise ValueError(f"Unsupported SVG command {token!r}")
            command = token
            index += 1
            if command == "Z":
                commands.append(["Z"])
                command = None
                continue
        elif command is None:
            raise ValueError(f"SVG path has coordinates without a command: {path_data}")

        if command == "M":
            values = _take_numbers(tokens, index, 2, path_data)
            index += 2
            commands.append(["M", *normalized_point(values[0], values[1])])
            command = "L"
        elif command == "L":
            values = _take_numbers(tokens, index, 2, path_data)
            index += 2
            commands.append(["L", *normalized_point(values[0], values[1])])
        elif command == "Q":
            values = _take_numbers(tokens, index, 4, path_data)
            index += 4
            commands.append(
                [
                    "Q",
                    *normalized_point(values[0], values[1]),
                    *normalized_point(values[2], values[3]),
                ]
            )
        elif command == "C":
            values = _take_numbers(tokens, index, 6, path_data)
            index += 6
            commands.append(
                [
                    "C",
                    *normalized_point(values[0], values[1]),
                    *normalized_point(values[2], values[3]),
                    *normalized_point(values[4], values[5]),
                ]
            )
        else:
            raise ValueError(f"Unsupported SVG command {command!r}")

    if not commands or commands[-1][0] != "Z":
        raise ValueError(f"SVG path is not closed: {path_data}")
    return commands


def _take_numbers(
    tokens: list[str], index: int, count: int, path_data: str
) -> list[float]:
    end = index + count
    values = tokens[index:end]
    if len(values) != count or any(value.isalpha() for value in values):
        raise ValueError(f"SVG path has incomplete command data: {path_data}")
    return [float(value) for value in values]


def convert_record(record: dict[str, Any]) -> dict[str, Any]:
    character = record.get("character")
    strokes = record.get("strokes")
    medians = record.get("medians")
    if not isinstance(character, str) or len(character) != 1:
        raise ValueError("graphics record has an invalid character")
    if not isinstance(strokes, list) or not isinstance(medians, list):
        raise ValueError(f"graphics record for {character} is missing strokes or medians")
    if len(strokes) != len(medians) or not strokes:
        raise ValueError(f"graphics record for {character} has mismatched stroke data")

    converted_strokes = []
    for path_data, median in zip(strokes, medians):
        if not isinstance(path_data, str) or not isinstance(median, list):
            raise ValueError(f"graphics record for {character} has malformed stroke data")
        if len(median) < 2:
            raise ValueError(f"graphics record for {character} has a short median")
        converted_strokes.append(
            {
                "path": parse_svg_path(path_data),
                "median": [
                    normalized_point(float(point[0]), float(point[1]))
                    for point in median
                    if isinstance(point, list) and len(point) == 2
                ],
            }
        )
        if len(converted_strokes[-1]["median"]) != len(median):
            raise ValueError(f"graphics record for {character} has malformed median data")

    return {"character": character, "strokes": converted_strokes}


def required_characters(vocabulary_root: Path) -> set[str]:
    characters: set[str] = set()
    for level in range(1, 8):
        vocabulary_path = vocabulary_root / f"hsk{level}.json"
        words = json.loads(vocabulary_path.read_text(encoding="utf-8"))
        for word in words:
            characters.update(
                character
                for character in word["simplified"]
                if is_hanzi(character)
            )
    return characters


def build_catalog(source_path: Path, vocabulary_root: Path) -> dict[str, dict[str, Any]]:
    required = required_characters(vocabulary_root)
    records: dict[str, dict[str, Any]] = {}

    with source_path.open(encoding="utf-8") as source_file:
        for line in source_file:
            record = json.loads(line)
            character = record.get("character")
            if character not in required:
                continue
            if character in records:
                raise ValueError(f"duplicate graphics record for {character}")
            records[character] = convert_record(record)

    missing = sorted(required - records.keys())
    if missing:
        raise ValueError(f"missing stroke data for {len(missing)} characters: {''.join(missing)}")
    return {character: records[character] for character in sorted(records)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--vocabulary-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    catalog = build_catalog(args.source, args.vocabulary_root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(catalog)} characters to {args.output}")


if __name__ == "__main__":
    main()
