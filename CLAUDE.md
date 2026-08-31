# CLAUDE.md

Context for working on this repo. `README.md` is user-facing — keep it to
what it does / how to set it up, not internals.

## What it is

A yazi plugin: hovering a directory that contains images shows an
ImageMagick `montage` contact sheet (up to 9 images, evenly sampled) instead
of a file listing. Folders with no images fall back to an `eza` listing so
normal navigation is unaffected. `main.lua` + `package.toml`.

## Where it lives

Repo is `~/Projects/image-grid.yazi`, symlinked to
`~/.config/yazi/plugins/image-grid.yazi` — edits here are live on the next
hover. Public repo `DragoshiUk/image-grid.yazi`.

## Structure

- `M:preload(job)` builds the montage into yazi's cache and returns
  `1` = grid ready, `0` = no images / error (peek falls back), `2` = busy.
- `M:peek(job)` shows the cached montage, or calls `render_listing()` (the
  eza fallback) when preload returns 0.
- `M:seek(job)` scrolls the fallback listing.
- Registered as **both** a previewer and a preloader for `folder/*` in
  `yazi.toml`.

## Load-bearing details

- **The eza fallback is fully async and deliberately does not delegate to
  yazi's own `folder.lua`.** `folder.lua`'s peek reads the global `cx`,
  which doesn't exist in this plugin's async context — hence the hand-rolled
  `Command("eza")` + `read_line` loop, mirroring `eza-preview.yazi`.
- **`MAX_CONCURRENT` throttle** (default 3) keeps `montage` processes from
  piling up while scrolling through many folders; mirrors `video-grid.yazi`.
- **Representative sampling**: `sample()` picks evenly-spaced files across
  the sorted directory, not the first N, so a big folder's grid is
  representative. `tile_for()` picks the grid shape (1x1 … 3x3) from count.
- Tunables are constants at the top of `main.lua`: `MAX_IMAGES`,
  `CELL_SIZE`, `GUTTER`, `MAX_CONCURRENT`, `IMAGE_EXT`.

## Requirements

yazi >= 26.0.0, ImageMagick (`montage`), eza. Grid display needs a
kitty-graphics-capable terminal (it's `ya.image_show` of the cached PNG).

## Testing

Manual — hover an image folder (grid), a folder with no images (eza
listing), and scroll quickly through many folders (throttle holds).
