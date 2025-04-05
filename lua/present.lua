local M = {}

M.setup = function(opts)
	-- TODO: implement setup
	print("Setup for present.nvim is called")
end

---Parse lines from buffer into slide contents
---@param lines string[]: Buffer lines
---@return string[][]
local parse_slides = function(lines)
	local slides = {}
	local current_slide = {}

	local separator = "^#"

	for _, line in ipairs(lines) do
		if line:find(separator) then
			if #current_slide > 0 then
				table.insert(slides, current_slide)
			end

			current_slide = {}
		end

		table.insert(current_slide, line)
	end

	if #current_slide > 0 then
		table.insert(slides, current_slide)
	end

	return slides
end

---@class FloatingWindowOptions
---@field width? number Width of the window (default: 80% of editor width)
---@field height? number Height of the window (default: 80% of editor height)
---@field col? number Column position (default: centered)
---@field row? number Row position (default: centered)
---@field relative? string Position relative to ("editor", "win", "cursor", etc.) (default: "editor")
---@field style? string Window style ("minimal", etc.) (default: "minimal")
---@field border? string|table Border style ("none", "single", "double", "rounded", etc.) (default: "rounded")
---@field title? string Window title
---@field title_pos? string Title position ("left", "center", "right")
---@field filetype? string Buffer filetype

---Creates a floating window with customizable options
---@param opts? FloatingWindowOptions Configuration options for the floating window
---@return { buf: number, win: number } # Buffer and window IDs
local create_floating_window = function(opts)
	-- Set default options if not provided
	opts = opts or {}

	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)

	-- Calculate centered position if not specified
	local col = opts.col or math.floor((vim.o.columns - width) / 2)
	local row = opts.row or math.floor((vim.o.lines - height) / 2)

	-- Configure window options
	local window_opts = {
		relative = opts.relative or "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = opts.style or "minimal",
		border = opts.border or "rounded",
		title = opts.title,
		title_pos = opts.title_pos,
	}

	-- Create a scratch buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)

	-- Create the floating window
	local win_id = vim.api.nvim_open_win(buf, true, window_opts)

	-- Set buffer options
	if opts.filetype then
		vim.api.nvim_buf_set_option(buf, "filetype", opts.filetype)
	end

	-- Return both buffer and window IDs for further manipulation
	return {
		buf = buf,
		win = win_id,
	}
end

---Start new presentation
---@param opts? { bufnr?: number } Presentation options
---@return nil
M.start_presentation = function(opts)
	opts = opts or {}
	opts.bufnr = opts.bufnr or 0

	local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
	local slides = parse_slides(lines)
	local floating_window = create_floating_window()

	local current_slide = 1
	local show_slide = function()
		vim.api.nvim_buf_set_lines(floating_window.buf, 0, -1, false, slides[current_slide])
	end

	vim.keymap.set("n", "n", function()
		current_slide = math.min(current_slide + 1, #slides)
		show_slide()
	end, { buffer = floating_window.buf, desc = "Show next slide" })

	vim.keymap.set("n", "p", function()
		current_slide = math.max(current_slide - 1, 1)
		show_slide()
	end, { buffer = floating_window.buf, desc = "Show previous slide" })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(floating_window.win, true)
	end, { buffer = floating_window.buf, desc = "Close sides" })

	show_slide()
end

-- M.start_presentation({ bufnr = 50 })

return M
