import sqlite3
import json
from PIL import Image
from pathlib import Path
from dataclasses import dataclass
from typing import NamedTuple
from google.protobuf import descriptor_pb2, descriptor_pool
from google.protobuf.message_factory import GetMessageClass

# Constants
CONFIG_PATH = Path("config.json")
CHUNK_WIDTH: int = 32

@dataclass
class BlockPosition:
    x: int = 0
    z: int = 0

    def in_bounds(self, topleft: "BlockPosition", bottomleft: "BlockPosition") -> bool:
        return topleft.x <= self.x <= bottomleft.x and topleft.z <= self.z <= bottomleft.z

class MapBounds(NamedTuple):
    topleft: BlockPosition
    bottomleft: BlockPosition

class Color(NamedTuple):
    r: int
    g: int
    b: int

@dataclass
class MapPiece:
    chunk_position: int # encoded
    pixels_blob: bytes # protobuf encoded

    def get_block_position(self) -> BlockPosition:
        chunk_x = (self.chunk_position & ((1 << 21) - 1))  # bits 0–20
        chunk_z = (self.chunk_position >> 27) & ((1 << 21) - 1)  # bits 28–49
        return BlockPosition(chunk_x * CHUNK_WIDTH, chunk_z * CHUNK_WIDTH)
    
    def get_colors(self, protobuf_class) -> list[Color]:
        colors = []
        msg = protobuf_class()
        msg.ParseFromString(self.pixels_blob)
        pixels = msg.pixels
        for pixel in pixels:
            # Assuming the pixel is stored as a 32-bit integer (RGBA)
            r = pixel & 0xFF
            g = (pixel >> 8) & 0xFF
            b = (pixel >> 16) & 0xFF
            colors.append(Color(r, g, b))
        return colors


class Config(NamedTuple):
    db_path: Path
    output_path: Path
    map_bounds: MapBounds


def load_user_config(config_path: Path):
    if not config_path.is_file():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with config_path.open("r", encoding="utf-8") as f:
        config = json.load(f)

    required_keys = ["map_file", "output", "min_x", "max_x", "min_z", "max_z"]
    for key in required_keys:
        if key not in config:
            raise KeyError(f"Missing key in config: {key}")

    map_file_path = Path(config["map_file"])
    if not map_file_path.is_file():
        raise FileNotFoundError(f"Worldmap database file not found: {map_file_path}")

    if not (config["min_x"] <= config["max_x"] and config["min_z"] <= config["max_z"]):
        raise ValueError("You should have min_x <= max_x and min_z <= max_z")

    return Config(
        db_path=Path(config["map_file"]),
        output_path=Path(config["output"]),
        map_bounds=MapBounds(
            topleft=BlockPosition(config["min_x"], config["min_z"]),
            bottomleft=BlockPosition(config["max_x"], config["max_z"])
        )
    )

def create_map_piece_colors_message():
    file_desc_proto = descriptor_pb2.FileDescriptorProto()
    file_desc_proto.name = "map_piece_colors.proto"
    file_desc_proto.package = "dynamic"

    msg = file_desc_proto.message_type.add()
    msg.name = "MapPieceColors"

    field = msg.field.add()
    field.name = "pixels"
    field.number = 1
    field.label = descriptor_pb2.FieldDescriptorProto.LABEL_REPEATED
    field.type = descriptor_pb2.FieldDescriptorProto.TYPE_INT32

    pool = descriptor_pool.Default()
    file_desc = pool.Add(file_desc_proto)

    descriptor = file_desc.message_types_by_name["MapPieceColors"]
    return GetMessageClass(descriptor)


def int_to_rgb(pixel_value: int):
    return (
        pixel_value & 0xFF,           # Red
        (pixel_value >> 8) & 0xFF,    # Green
        (pixel_value >> 16) & 0xFF    # Blue
    )


def main():
    config = load_user_config(CONFIG_PATH)
    MapPieceColors = create_map_piece_colors_message()

    bounds = config.map_bounds
    min_x, min_z = bounds.topleft.x, bounds.topleft.z
    max_x, max_z = bounds.bottomleft.x, bounds.bottomleft.z

    width_in_blocks = max_x - min_x + 1
    height_in_blocks = max_z - min_z + 1
    image = Image.new("RGB", (width_in_blocks, height_in_blocks))

    conn = sqlite3.connect(config.db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT position, data FROM mappiece")

    count = 0
    for chunk_pos, data in cursor:
        map_piece = MapPiece(chunk_pos, data)
        block_pos = map_piece.get_block_position()

        if not block_pos.in_bounds(bounds.topleft, bounds.bottomleft):
            #print(f"Chunk {block_pos} out of bounds, skipping")
            continue

        colors: list[Color] = map_piece.get_colors(MapPieceColors)
        chunk_width = CHUNK_WIDTH

        for dz in range(chunk_width):
            for dx in range(chunk_width):
                idx = dz * chunk_width + dx
                pixel_x = block_pos.x + dx - min_x
                pixel_z = block_pos.z + dz - min_z
                if 0 <= pixel_x < width_in_blocks and 0 <= pixel_z < height_in_blocks:
                    image.putpixel((pixel_x, pixel_z), colors[idx])

        count += 1

    print(f"{count} chunks processed")
    image.save(config.output_path)
    print(f"Image saved as {config.output_path}")



if __name__ == "__main__":
    main()