import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import List, NamedTuple

import betterproto
from PIL import Image


# Constants
CONFIG_PATH = Path("config.json")
CHUNK_WIDTH: int = 32


@dataclass
class BlockPosition:
    x: int = 0
    z: int = 0

    def in_bounds(self, topleft: "BlockPosition", bottomright: "BlockPosition") -> bool:
        return topleft.x <= self.x <= bottomright.x and topleft.z <= self.z <= bottomright.z


class MapBounds(NamedTuple):
    topleft: BlockPosition
    bottomright: BlockPosition


class Color(NamedTuple):
    r: int
    g: int
    b: int

    @classmethod
    def from_int32(cls, value: int) -> "Color":
        return cls(
            r=value & 0xFF,
            g=(value >> 8) & 0xFF,
            b=(value >> 16) & 0xFF
        )


@dataclass
class MapPiecePixelsMessage(betterproto.Message):
    """
    Protobuf message used by Vintage Story to store pixel colors of map pieces.  
    https://github.com/bluelightning32/vs-proto/blob/main/schema-1.19.8.proto#L70

    The 'pixels' field is a list of 32-bit integers, encoded by protobuf.  
    Each integer encodes a pixel color using Vintage Story's custom color format,  
    with pixels stored in row-major order.
    """
    pixels: List[int] = betterproto.int32_field(1)


@dataclass
class MapPiece:
    chunk_position: int # encoded
    pixels_blob: bytes # protobuf encoded

    def get_block_position(self) -> BlockPosition:
        chunk_x = (self.chunk_position & ((1 << 21) - 1))  # bits 0–20
        chunk_z = (self.chunk_position >> 27) & ((1 << 21) - 1)  # bits 28–49
        return BlockPosition(chunk_x * CHUNK_WIDTH, chunk_z * CHUNK_WIDTH)
    
    def decode_pixels(self) -> List[Color]:
        pixels: List[int] = MapPiecePixelsMessage().parse(self.pixels_blob).pixels
        return [Color.from_int32(pixel) for pixel in pixels]


@dataclass
class Config:
    db_path: Path
    output_path: Path
    map_bounds: MapBounds

    @classmethod
    def from_file(cls, config_path: Path) -> "Config":
        if not config_path.is_file():
            raise FileNotFoundError(f"Config file not found: {config_path}")

        with config_path.open("r", encoding="utf-8") as f:
            config = json.load(f)

        cls._validate_config_dict(config)

        return cls(
            db_path=Path(config["map_file"]),
            output_path=Path(config["output"]),
            map_bounds=MapBounds(
                topleft=BlockPosition(config["min_x"], config["min_z"]),
                bottomright=BlockPosition(config["max_x"], config["max_z"]),
            )
        )

    @staticmethod
    def _validate_config_dict(config: dict) -> None:
        required_keys = {"map_file", "output", "min_x", "max_x", "min_z", "max_z"}
        missing = required_keys - config.keys()
        if missing:
            raise KeyError(f"Missing keys in config: {', '.join(missing)}")

        if config["min_x"] > config["max_x"] or config["min_z"] > config["max_z"]:
            raise ValueError("Invalid map bounds: min_x <= max_x and min_z <= max_z required")

        if not Path(config["map_file"]).is_file():
            raise FileNotFoundError(f"Worldmap database file not found: {config['map_file']}")


def main():
    config = Config.from_file(CONFIG_PATH)

    bounds = config.map_bounds
    width_in_blocks = bounds.bottomright.x - bounds.topleft.x + 1
    height_in_blocks = bounds.bottomright.z - bounds.topleft.z + 1
    image = Image.new("RGB", (width_in_blocks, height_in_blocks))

    conn = sqlite3.connect(config.db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT position, data FROM mappiece")

    count = 0
    for position, data in cursor:
        map_piece = MapPiece(position, data)
        block_pos = map_piece.get_block_position()

        if not block_pos.in_bounds(bounds.topleft, bounds.bottomright):
            #print(f"Chunk {block_pos} out of bounds, skipping")
            continue

        colors: List[Color] = map_piece.decode_pixels()

        for dz in range(CHUNK_WIDTH):
            for dx in range(CHUNK_WIDTH):
                idx = dz * CHUNK_WIDTH + dx
                pixel_x = block_pos.x + dx - bounds.topleft.x
                pixel_z = block_pos.z + dz - bounds.topleft.z
                if 0 <= pixel_x < width_in_blocks and 0 <= pixel_z < height_in_blocks:
                    image.putpixel((pixel_x, pixel_z), colors[idx])
        count += 1

    print(f"{count} chunks processed")
    image.save(config.output_path)
    print(f"Image saved as {config.output_path}")


if __name__ == "__main__":
    main()