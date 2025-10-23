# 🗺️ VS Map Renderer

**VS Map Renderer** is a tool that reads color data from your [Vintage Story](https://www.vintagestory.at/) client-side minimap, and exports it as a high-resolution PNG image. You can choose to render a specific region using coordinate bounds, or export the **entire explored world**.

The output is **pixel-perfect**: each block in the game is mapped to exactly one pixel in the image. **No scaling, no blurring, no interpolation**.

Compared to [Vintage Story Map Exporter](https://mods.vintagestory.at/vsdbtopng), this tool is:

- 💻 **Cross-platform** (runs on Linux, macOS, and Windows)
- 📏 **Not limited** to 10,000×10,000 pixels
- 🌍 **Can render the whole explored map automatically**, no manual bounds needed
- 🧭 **Supports relative coordinates** (the ones you see in-game)

## Preview

<p align="center"><img src="etc/readme_preview.png" alt="Preview of the software UI"/></p>

<p align="center"><img src="etc/readme_map.png" alt="Preview of exported map"/></p>

1,500×1,000 blocks  
_Map colors are from the [Medieval Map](https://mods.vintagestory.at/marximusmedievalmap) mod._

## Installation

From the Releases page, download the [latest version](https://github.com/elliotfontaine/vsmaptools/releases) corresponding to your operating system.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
