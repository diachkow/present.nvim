local M = {}

M.setup = function(opts)
  -- Empty for now, we'll see if there would be any configurable arguments in the future
end

---@class present.Slide
---@field header string: Slide headline
---@field body string[]: Slide contents (each line is a separate string)

---Parse lines from buffer into slide contents
---@param lines string[]: Buffer lines
---@return present.Slide[]
local parse_slides = function(lines)
  local slides = {}
  local current_slide = { header = "", body = {} }

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.header > 0 then
        table.insert(slides, current_slide)
      end

      current_slide = { header = line, body = {} }
    else
      table.insert(current_slide.body, line)
    end
  end

  if #current_slide.body > 0 then
    table.insert(slides, current_slide)
  end

  return slides
end

---@class present.FloatingWindow
---@field buf number Created buffer ID
---@field win number Created window ID

---Creates a floating window with provided window config
---@param win_config vim.api.keyset.win_config Configuration for floating window
---@param filetype? string Optional filetype to set newly created buffer to
---@param enter? boolean Optional, if to set window as active
---@return present.FloatingWindow # Buffer and window IDs
local create_floating_window = function(win_config, filetype, enter)
  local buf = vim.api.nvim_create_buf(false, true)
  if filetype then
    vim.bo[buf].filetype = filetype
  end

  if enter == nil then
    enter = false
  end

  local win = vim.api.nvim_open_win(buf, enter, win_config)
  return { buf = buf, win = win }
end

---@class present.WindowConfigs
---@field background vim.api.keyset.win_config
---@field header vim.api.keyset.win_config
---@field body vim.api.keyset.win_config
---@field footer vim.api.keyset.win_config

---Populate window configs for presentation
---@return present.WindowConfigs
local create_window_configurations = function()
  local width = vim.o.columns
  local height = vim.o.lines

  return {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = "minimal",
      col = 0,
      row = 0,
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      col = 1,
      row = 0,
      zindex = 2,
    },
    body = {
      relative = "editor",
      width = width - math.floor(width * 0.1),
      height = height - math.max(4, math.floor(height * 0.02)) - 1,
      style = "minimal",
      col = math.floor(width * 0.05),
      row = 3,
      zindex = 2,
    },
    footer = {
      relative = "editor",
      width = width - math.floor(width * 0.1),
      height = 1,
      style = "minimal",
      col = math.floor(width * 0.05),
      row = height - 1,
      zindex = 2,
    },
  }
end

---@class present.FloatingWindowCollection
---@field background present.FloatingWindow
---@field body present.FloatingWindow
---@field header present.FloatingWindow
---@field footer present.FloatingWindow

---@class present.State
---@field current_slide number Number of current slide drawn
---@field slides_filename string Name of the original file that have file contents
---@field slides present.Slide[] Array of parsed slides for presentation
---@field floats present.FloatingWindowCollection

---@type present.State
local state = {
  current_slide = -1,
  slides = {},
  floats = {}, ---@diagnostic disable-line
  slides_filename = "",
}

local set_presentation_keymap = function(mode, key, callback, desc)
  vim.keymap.set(mode, key, callback, { buffer = state.floats.body.buf, desc = desc })
end

local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

---Start new presentation
---@param opts? { bufnr?: number } Presentation options
---@return nil
M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)

  -- Set state to the starting values
  state.slides = parse_slides(lines)
  state.current_slide = 1
  state.slides_filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

  -- Create floating windows to view slides contents
  local windows = create_window_configurations()

  state.floats.background = create_floating_window(windows.background)
  state.floats.header = create_floating_window(windows.header, "markdown")
  state.floats.footer = create_floating_window(windows.footer, "markdown")
  state.floats.body = create_floating_window(windows.body, "markdown", true)

  local show_slide = function()
    local width = vim.o.columns
    local slide = state.slides[state.current_slide]

    local padding = string.rep(" ", (width - #slide.header) / 2)
    local header_text = padding .. slide.header
    local footer_content =
      string.format("  Slide %d / %d | %s", state.current_slide, #state.slides, state.slides_filename)

    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { header_text })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer_content })

    local last_line = vim.api.nvim_buf_line_count(state.floats.body.buf)
    vim.api.nvim_win_set_cursor(state.floats.body.win, { last_line, 0 })
  end

  set_presentation_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.slides)
    show_slide()
  end, "Show next slide")

  set_presentation_keymap("n", "p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    show_slide()
  end, "Show previous slide")

  set_presentation_keymap("n", "q", function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end, "Close slides")

  local presentation_options_overrides = {
    cmdheight = {
      original = vim.o.cmdheight,
      presentation = 0,
    },
  }

  -- Override options during presentation time
  for option, config in pairs(presentation_options_overrides) do
    vim.opt[option] = config.presentation
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.floats.body.buf,
    callback = function()
      -- Restore options back after presentation is closed
      for option, config in pairs(presentation_options_overrides) do
        vim.opt[option] = config.original
      end

      -- Also close the other opened windows
      foreach_float(function(_, float)
        pcall(vim.api.nvim_win_close, float.win, true)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("present-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
        return
      end

      local updated = create_window_configurations()
      foreach_float(function(_, float)
        vim.api.nvim_win_set_config(float.win, updated.background)
      end)

      -- Update contents according to the updated width (re-center header)
      show_slide()
    end,
  })

  show_slide()
end

-- Add parse slides function to module exports, but mark it as `private`
-- This way, it is not exposed as public API of my plugin, but at the same
-- time it is available to test
M._parse_slides = parse_slides

return M
