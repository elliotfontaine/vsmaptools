# 🗺️ VS Map Renderer

**VS Map Renderer** is a tool that reads color data from your [Vintage Story](https://www.vintagestory.at/) client-side minimap, and exports it as a high-resolution PNG image. You can choose to render a specific region using coordinate bounds, or export the **entire explored world**.

The output is **pixel-perfect**: each block in the game is mapped to exactly one pixel in the image. **No scaling, no blurring, no interpolation**.

Compared to [Vintage Story Map Exporter](https://mods.vintagestory.at/vsdbtopng), this tool is:

- 💻 **Cross-platform** (runs on Linux, macOS, and Windows)
- 📏 **Not limited** to 10,000×10,000 pixels
- 🌍 **Can render the whole explored map automatically**, no manual bounds needed
- 🧭 **Supports relative coordinates** (the ones you see in-game)

## Preview

<p align="center"><img src="img/terminal_output.gif?raw=true" width="500"/></p>

<p align="center"><img src="img/5k_5k_map.png" alt="Preview of exported map" width="500"/></p>

5,000×5,000 blocks  
_Map colors are from the [Medieval Map](https://mods.vintagestory.at/marximusmedievalmap) mod._

## Installation

This project requires Python 3.7 or higher.

1. [Install Python](https://www.python.org/downloads/) if you don't already have it.

2. Download the [latest release](https://github.com/elliotfontaine/vsmaptools/releases/latest) of **VS Map Renderer**. It should include:

   - `vsmaptools.py` — the main script
   - `requirements.txt` — dependency list
   - `config.json` — configuration example

3. Install required Python packages:
   ```shell
   pip install -r requirements.txt
   ```

## Configuration

The tool uses a JSON configuration file specifying the input minimap database, output image filename, and the coordinate bounds for the map area you want to export.

### `config.json`

```json
{
  "map_file": "17036cd4-fd1c-4c2b-87ff-5c5e3fe6eee7.db",
  "output": "vs_worldmap.png",
  "whole_map": true,
  "min_x": -1000,
  "max_x": 1000,
  "min_z": -1000,
  "max_z": 1000,
  "use_relative_coord": true,
  "spawn_abs_x": 512000,
  "spawn_abs_z": 512000
}
```

- **`map_file`**: Path to your minimap file.
- **`output`**: Path/filename for the exported PNG image.
- **`whole_map`**: If true, exports the entire map area covered by existing chunks in the minimap database. When enabled, all coordinate-related fields below are ignored.
- **`min_x`, `max_x`**: X-coordinate range of the region to export.
- **`min_z`, `max_z`**: Z-coordinate range of the region to export.
- **`use_relative_coord`**: If true, the coordinate bounds are interpreted relative to the player's spawn location. In that case, `spawn_x` and `spawn_z` must be provided.
- **`spawn_x`, `spawn_z`**: Absolute coordinates of the player's spawn point. Only processed if `use_relative_coord` is true.

**Coordinates:** Vintage Story uses [two coordinates systems](https://wiki.vintagestory.at/Coordinates), absolute and relative to spawnpoint. While in-game, use the `.cp aposi` command in chat to copy your current _absolute_ position to the clipboard. Do that at the top-left and bottom-right bounds you want to render (or at your spawn point, if using relative coordinates).  
The default spawn point is located at the center of the world. For example, in a 1M-wide world, the center is at `x=512000; z=512000`.

**Minimap files:** Map `.db` files are stored in the [VintagestoryData/Maps](https://wiki.vintagestory.at/VintagestoryData_folder) folder of your game. For convenience (and to avoid any risk of file corruption), you may want to copy the map file into the directory where you're running `vsmaptools.py`.

## Usage

Run the script from the command-line with Python:

```shell
python3 vsmaptools.py
```

The image will be generated at the path specified in `config.json`.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
