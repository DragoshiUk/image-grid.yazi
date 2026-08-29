local M = {}

-- ─────────────────────────────────────────────────────────────
--  CONFIGURATION
-- ─────────────────────────────────────────────────────────────

-- Sample at most this many images per directory for the grid
local MAX_IMAGES = 9

-- Cell size (each tile is scaled/cropped to fit WxH), with a small gutter
local CELL_SIZE = 300
local GUTTER    = 4

-- Max concurrent montage processes (mirrors video-grid.yazi's throttle)
local MAX_CONCURRENT = 3

local IMAGE_EXT = {
	jpg = true, jpeg = true, png = true, gif = true, bmp = true,
	webp = true, avif = true, heic = true, heif = true, tiff = true, tif = true,
}

local active_jobs = 0

local function is_image(url)
	local ext = url.ext and url.ext:lower()
	return ext and IMAGE_EXT[ext] or false
end

-- Pick up to `n` entries, evenly spaced across the sorted list, so a big
-- folder's grid is a representative sample rather than just the first N.
local function sample(list, n)
	if #list <= n then
		return list
	end
	local out = {}
	for i = 1, n do
		local idx = math.floor((i - 1) * (#list - 1) / (n - 1)) + 1
		out[i] = list[idx]
	end
	return out
end

local function tile_for(n)
	if n <= 1 then return "1x1" end
	if n <= 2 then return "2x1" end
	if n <= 4 then return "2x2" end
	if n <= 6 then return "3x2" end
	return "3x3"
end

-- ─────────────────────────────────────────────────────────────
--  FALLBACK: eza-based directory listing for folders with no images.
--  Fully async (no `cx` access), mirroring eza-preview.yazi's approach —
--  delegating to yazi's own folder.lua isn't possible here since its
--  peek reads the global `cx`, which doesn't exist in our async context.
-- ─────────────────────────────────────────────────────────────
local function render_listing(job)
	local child, err = Command("eza")
		:arg("--color=always")
		:arg("--group-directories-first")
		:arg("--icons=always")
		:arg("--no-quotes")
		:arg(tostring(job.file.url))
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		return ya.preview_widget(job, ui.Text("eza: " .. (err or "spawn failed")):area(job.area))
	end

	local limit = job.area.h
	local lines, line_count, skipped = "", 0, 0
	repeat
		local line, event = child:read_line()
		if event == 1 then
			-- stderr, ignore
		elseif event ~= 0 then
			break
		elseif skipped < job.skip then
			skipped = skipped + 1
		else
			lines = lines .. line
			line_count = line_count + 1
		end
	until line_count >= limit

	child:start_kill()

	if job.skip > 0 and line_count < limit then
		return ya.emit("peek", {
			math.max(0, job.skip - (limit - line_count)),
			only_if = job.file.url,
			upper_bound = true,
		})
	elseif line_count == 0 then
		return ya.preview_widget(job, { ui.Text({ ui.Line("No items") }):area(job.area):align(ui.Align.CENTER) })
	end
	return ya.preview_widget(job, { ui.Text.parse(lines):area(job.area) })
end

-- ─────────────────────────────────────────────────────────────
--  PEEK: show the cached grid, or fall back to an eza listing
--  when there are no images to grid up.
-- ─────────────────────────────────────────────────────────────
function M:peek(job)
	local cache = ya.file_cache(job)
	if cache and self:preload(job) == 1 then
		ya.image_show(cache, job.area)
		return ya.preview_widget(job, {})
	end
	return render_listing(job)
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = job.file.url,
			force = true,
		})
	end
end

-- ─────────────────────────────────────────────────────────────
--  PRELOAD: build the montage into yazi's cache
--  Returns: 1 = grid ready, 0 = no images / error (use fallback),
--           2 = busy, retry
-- ─────────────────────────────────────────────────────────────
function M:preload(job)
	if job.skip > 0 then
		return 1
	end

	local cache = ya.file_cache(job)
	if not cache then
		return 0
	end
	if fs.cha(cache) then
		return 1 -- cache hit
	end

	local files = fs.read_dir(job.file.url, {})
	if not files then
		return 0
	end

	local images = {}
	for _, f in ipairs(files) do
		if not (f.cha and f.cha.is_dir) and is_image(f.url) then
			images[#images + 1] = f.url
		end
	end
	if #images == 0 then
		return 0 -- no images here, let peek fall back to the folder listing
	end

	table.sort(images, function(a, b) return a.name < b.name end)
	images = sample(images, MAX_IMAGES)

	if active_jobs >= MAX_CONCURRENT then
		return 2
	end
	active_jobs = active_jobs + 1

	local cmd = Command("montage")
	for _, url in ipairs(images) do
		cmd = cmd:arg(tostring(url))
	end
	-- "jpg:" forces JPEG output regardless of the cache path's extension
	cmd = cmd
		:arg("-tile"):arg(tile_for(#images))
		:arg("-geometry"):arg(string.format("%dx%d+%d+%d", CELL_SIZE, CELL_SIZE, GUTTER, GUTTER))
		:arg("-background"):arg("#1e1e1e")
		:arg("jpg:" .. tostring(cache))

	local child, err_code = cmd:spawn()
	if not child then
		active_jobs = active_jobs - 1
		ya.err(string.format(
			"[image-grid] ERROR spawn montage: %s — code: %s",
			tostring(job.file.url), tostring(err_code)
		))
		return 0
	end

	local status = child:wait()
	active_jobs = active_jobs - 1

	if status and status.success then
		return 1
	end
	ya.err(string.format(
		"[image-grid] ERROR montage exit: %s — status: %s",
		tostring(job.file.url), tostring(status and status.code)
	))
	return 0
end

return M
