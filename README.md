# image-grid.yazi

A [yazi](https://github.com/sxyazi/yazi) plugin that shows a **thumbnail grid preview** for directories full of images, right in the preview pane — no external viewer, no overlay.

Hover a folder and, if it contains images, you get a contact-sheet montage instead of a plain file listing. Folders without images fall back to a normal (colorized, icons-and-all) directory listing, so regular navigation is unaffected.

## Features

- 🖼️ **Grid preview for image folders** — up to 9 images sampled evenly across the directory and tiled into one montage (1×1 up to 3×3 depending on count)
- 🎯 **Representative sampling** — for folders with more than 9 images, picks evenly-spaced files rather than just the first few
- 💾 **Cached** — the montage is generated once per directory and reused, like any other yazi thumbnail
- ↩️ **Automatic fallback** — directories with no images show a normal colorized/icon file listing instead of the grid
- ⚡ **Throttled** — a concurrency limit keeps `montage` from piling up while scrolling through many folders quickly

## Requirements

- [yazi](https://github.com/sxyazi/yazi) `>= 26.0.0`
- [ImageMagick](https://imagemagick.org/) — provides `montage`, used to build the grid
- [eza](https://github.com/eza-community/eza) — used for the fallback directory listing

## Installation

**Via yazi's package manager (recommended):**

```bash
ya pkg add DragoshiUk/image-grid
```

**Manual:**

```bash
git clone https://github.com/DragoshiUk/image-grid.yazi.git \
  ~/.config/yazi/plugins/image-grid.yazi
```

## Setup

Register the plugin as the previewer and preloader for directories in `~/.config/yazi/yazi.toml`:

```toml
[plugin]
prepend_previewers = [
    { mime = "folder/*", run = "image-grid" },
]

prepend_preloaders = [
    { mime = "folder/*", run = "image-grid" },
]
```

## Configuration

Tunables live as constants at the top of `main.lua`:

| Constant          | Default | Meaning                                      |
|-------------------|---------|-----------------------------------------------|
| `MAX_IMAGES`       | `9`     | Max images sampled per directory              |
| `CELL_SIZE`        | `300`   | Each tile's target size in pixels             |
| `GUTTER`           | `4`     | Spacing between tiles in pixels               |
| `MAX_CONCURRENT`   | `3`     | Max concurrent `montage` processes            |
| `IMAGE_EXT`        | —       | Extensions treated as images                  |

## License

MIT
