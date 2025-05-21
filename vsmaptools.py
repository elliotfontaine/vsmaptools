#!/usr/bin/env python3
"""
vsmaptools.py
Version 1.1.0
Tool to read Vintage Story map database and export as PNG.
"""

import json
import sqlite3
import sys
import time
from argparse import ArgumentParser
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass
from operator import methodcaller
from pathlib import Path
from typing import Generator, Iterable, List, NamedTuple, Optional, Sized, TypeVar, cast

import betterproto
from PIL import Image

T = TypeVar("T")

__version__ = "1.1.0"

# Constants
CONFIG_PATH = Path("config.json")
CHUNK_WIDTH: int = 32


@dataclass
class BlockPosition:
    """An absolute block position on the world map."""

    x: int = 0
    z: int = 0


class MapBounds(NamedTuple):
    """2D rectangular bounds defining a region to render on the world map.

    The bounds are expressed in absolute block coordinates on the XZ-plane.
    They define the minimum and maximum corners of the rectangle (inclusive)."""

    top_left: BlockPosition
    bottom_right: BlockPosition

    @property
    def width(self) -> int:
        return self.bottom_right.x - self.top_left.x

    @property
    def height(self) -> int:
        return self.bottom_right.z - self.top_left.z


class Color(NamedTuple):
    """A single RGB color, extracted from the minimap pixel data."""

    r: int
    g: int
    b: int

    @classmethod
    def from_int32(cls, value: int) -> "Color":
        return cls(r=value & 0xFF, g=(value >> 8) & 0xFF, b=(value >> 16) & 0xFF)


@dataclass
class MapPiecePixelsMessage(betterproto.Message):
    """Protobuf message wrapper for map piece pixel data.

    See: https://github.com/bluelightning32/vs-proto/blob/main/schema-1.19.8.proto#L70

    The 'pixels' field is a list of 32-bit integers, encoded by protobuf.
    Each integer encodes a pixel color using Vintage Story's custom color format,
    with pixels stored in row-major order.
    """

    pixels: List[int] = betterproto.int32_field(1)


class MapPiece:
    """A minimap piece (chunk) containing pixel data and metadata.

    Each map piece represents a 32x32 block section of the world, stored in the
    player's minimap database.
    """

    top_left: BlockPosition
    pixels_blob: bytes  # protobuf encoded

    def __init__(self, chunk_position: int, pixels_blob: bytes) -> None:
        self.top_left = self._chunk_to_block_position(chunk_position)
        self.pixels_blob = pixels_blob

    @staticmethod
    def _chunk_to_block_position(chunk_position: int) -> BlockPosition:
        chunk_x = chunk_position & ((1 << 21) - 1)  # bits 0–20
        chunk_z = (chunk_position >> 27) & ((1 << 21) - 1)  # bits 28–49
        return BlockPosition(chunk_x * CHUNK_WIDTH, chunk_z * CHUNK_WIDTH)

    def intersects_bounds(self, bounds: MapBounds) -> bool:
        x, z = self.top_left.x, self.top_left.z
        return (x < bounds.bottom_right.x and x + CHUNK_WIDTH > bounds.top_left.x) and (
            z < bounds.bottom_right.z and z + CHUNK_WIDTH > bounds.top_left.z
        )

    def decode_pixels(self) -> List[Color]:
        pixels: List[int] = MapPiecePixelsMessage().parse(self.pixels_blob).pixels
        return [Color.from_int32(pixel) for pixel in pixels]

    def render(self) -> Image.Image:
        img = Image.new("RGB", (CHUNK_WIDTH, CHUNK_WIDTH))
        img.putdata(self.decode_pixels())
        return img


@dataclass
class Config:
    """Configuration state for VSMapTools.

    Reads and validates rendering parameters from a JSON configuration file.
    """

    db_path: Path
    output_path: Path
    whole_map: bool
    map_bounds: MapBounds

    @classmethod
    def from_file(cls, config_path: Path) -> "Config":
        if not config_path.is_file():
            raise FileNotFoundError(f"Config file not found: {config_path}")

        with config_path.open("r", encoding="utf-8") as f:
            config = json.load(f)

        cls._validate(config)

        if config.get("use_relative_coord"):
            min_x = config["spawn_abs_x"] + config["min_x"]
            max_x = config["spawn_abs_x"] + config["max_x"]
            min_z = config["spawn_abs_z"] + config["min_z"]
            max_z = config["spawn_abs_z"] + config["max_z"]
        else:
            min_x = config["min_x"]
            max_x = config["max_x"]
            min_z = config["min_z"]
            max_z = config["max_z"]

        return cls(
            db_path=Path(config["map_file"]),
            output_path=Path(config["output"]),
            whole_map=config["whole_map"],
            map_bounds=MapBounds(
                top_left=BlockPosition(min_x, min_z),
                bottom_right=BlockPosition(max_x, max_z),
            ),
        )

    @staticmethod
    def _validate(config: dict) -> None:
        required_keys = {
            "map_file",
            "output",
            "whole_map",
            "min_x",
            "max_x",
            "min_z",
            "max_z",
            "use_relative_coord",
            "spawn_abs_x",
            "spawn_abs_z",
        }
        missing = required_keys - config.keys()
        if missing:
            raise KeyError(f"Missing keys in config: {', '.join(missing)}")

        if config["use_relative_coord"]:
            if config["spawn_abs_x"] < 0 or config["spawn_abs_z"] < 0:
                raise ValueError("Spawn absolute coordinates must be non-negative.")
        else:
            if any(
                coord < 0
                for coord in (
                    config["min_x"],
                    config["max_x"],
                    config["min_z"],
                    config["max_z"],
                )
            ):
                raise ValueError(
                    "Coordinates must be non-negative when using absolute coordinates."
                )

        if config["min_x"] >= config["max_x"] or config["min_z"] >= config["max_z"]:
            raise ValueError(
                "Invalid map bounds: min_x < max_x and min_z < max_z required"
            )

        if not Path(config["map_file"]).is_file():
            raise FileNotFoundError(
                f"Worldmap database file not found: {config['map_file']}"
            )


def simple_progress_bar(
    iterable: Iterable[T],
    total: Optional[int] = None,
    bar_length: int = 20,
    min_interval: float = 0.1,
) -> Generator[T, None, None]:
    """
    A simple progress bar generator that yields items from an iterable
    while displaying a progress bar on the console.

    Args:
        iterable (Iterable[T]): The iterable to wrap with a progress bar.
        total (Optional[int], optional): Total number of items. If None,
            tries to infer length from the iterable. Defaults to None.
        bar_length (int, optional): The length of the progress bar in characters.
            Defaults to 20.
        min_interval (float, optional): Minimum seconds between updates to reduce overhead.
            Defaults to 0.1.

    Yields:
        T: Items from the original iterable.
    """

    def print_unbounded(i: int) -> None:
        sys.stdout.write(f"\rProcessed {i} items")
        sys.stdout.flush()

    def print_bounded(i: int, total: int) -> None:
        percent = i / total
        filled_length = int(bar_length * percent)
        progress_bar = "=" * filled_length + "-" * (bar_length - filled_length)
        sys.stdout.write(f"\r[{progress_bar}] {percent*100:3.0f}% ({i}/{total})")
        sys.stdout.flush()

    if total is None and hasattr(iterable, "__len__"):
        total = len(cast(Sized, iterable))

    last_update = 0.0
    for i, item in enumerate(iterable, 1):
        now = time.monotonic()
        should_update = now - last_update > min_interval
        is_final = total is not None and i == total

        if should_update or is_final:
            if total is None:
                print_unbounded(i)
            else:
                print_bounded(i, total)
            last_update = now
        yield item
    print()


def main() -> None:
    config = Config.from_file(CONFIG_PATH)

    print(f"Loading map pieces from {config.db_path}")
    conn = sqlite3.connect(config.db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT position, data FROM mappiece")
    map_pieces = [MapPiece(pos, data) for pos, data in cursor]
    print(f"{len(map_pieces)} map pieces loaded from the database.")
    conn.close()

    bounds, image = None, None

    if config.whole_map:
        xs = [piece.top_left.x for piece in map_pieces]
        zs = [piece.top_left.z for piece in map_pieces]
        bounds = MapBounds(
            top_left=BlockPosition(min(xs), min(zs)),
            bottom_right=BlockPosition(max(xs) + CHUNK_WIDTH, max(zs) + CHUNK_WIDTH),
        )
        image = Image.new("RGB", (bounds.width, bounds.height))
        print(f"Calculated whole map bounds: {bounds.top_left} - {bounds.bottom_right}")
    else:
        bounds = config.map_bounds
        image = Image.new("RGB", (bounds.width, bounds.height))
        map_pieces = [piece for piece in map_pieces if piece.intersects_bounds(bounds)]
        print(f"Filtered out of bounds map pieces, {len(map_pieces)} pieces remaining.")
    print(f"Image size: {bounds.width} x {bounds.height}")

    with ProcessPoolExecutor() as executor:
        rendered_images = executor.map(methodcaller("render"), map_pieces)
        for map_piece, piece_image in simple_progress_bar(
            zip(map_pieces, rendered_images), total=len(map_pieces)
        ):
            pixel_x = map_piece.top_left.x - bounds.top_left.x
            pixel_z = map_piece.top_left.z - bounds.top_left.z
            image.paste(piece_image, (pixel_x, pixel_z))
    print(f"Processed {len(map_pieces)} map pieces.")

    image.save(config.output_path)
    print(f"Image saved as {config.output_path}")


def profiled_main() -> None:
    import cProfile  # pylint: disable=import-outside-toplevel
    import pstats  # pylint: disable=import-outside-toplevel
    import io  # pylint: disable=import-outside-toplevel

    pr = cProfile.Profile()
    pr.enable()
    main()
    pr.disable()

    s = io.StringIO()
    ps = pstats.Stats(pr, stream=s).strip_dirs().sort_stats("cumtime")
    ps.print_stats(30)
    print(s.getvalue())


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "--profile", action="store_true", help="Enable profiling with cProfile"
    )
    args = parser.parse_args()

    if args.profile:
        profiled_main()
    else:
        main()
