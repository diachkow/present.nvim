local M = {}

M.setup = function(opts)
  -- TODO: implement setup
  print("Setup for present.nvim is called")
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

    table.insert(current_slide, line)
  end

  if #current_slide > 0 then
    table.insert(slides, current_slide)
  end

  return slides
end

---Creates a floating window with provided window config
---@param win_config vim.api.keyset.win_config Configuration for floating window
---@param filetype? string Optional filetype to set newly created buffer to
---@return { buf: number, win: number } # Buffer and window IDs
local create_floating_window = function(win_config, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  if filetype then
    vim.bo[buf].filetype = filetype
  end

  local win = vim.api.nvim_open_win(buf, true, win_config)
  return { buf = buf, win = win }
end

---@class present.WindowConfigs
---@field background vim.api.keyset.win_config
---@field header vim.api.keyset.win_config
---@field body vim.api.keyset.win_config

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
      height = height - math.max(4, math.floor(height * 0.02)),
      style = "minimal",
      col = math.floor(width * 0.05),
      row = 3,
      zindex = 2,
    },
    -- footer = {},
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

  -- Create floating windows to view slides contents
  local windows = create_window_configurations()

  local background_float = create_floating_window(windows.background)
  local header_float = create_floating_window(windows.header, "markdown")
  local body_float = create_floating_window(windows.body, "markdown")

  local current_slide = 1
  local show_slide = function()
    local width = vim.o.columns
    local slide = slides[current_slide]

    local padding = string.rep(" ", (width - #slide.header) / 2)
    local header_text = padding .. slide.header
    vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { header_text })
    vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
  end

  vim.keymap.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #slides)
    show_slide()
  end, { buffer = body_float.buf, desc = "Show next slide" })

  vim.keymap.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    show_slide()
  end, { buffer = body_float.buf, desc = "Show previous slide" })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(body_float.win, true)
  end, { buffer = body_float.buf, desc = "Close sides" })

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
    buffer = body_float.buf,
    callback = function()
      -- Restore options back after presentation is closed
      for option, config in pairs(presentation_options_overrides) do
        vim.opt[option] = config.original
      end

      -- Also close the other opened windows
      pcall(vim.api.nvim_win_close, background_float.win, true)
      pcall(vim.api.nvim_win_close, header_float.win, true)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("present-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(body_float.win) or body_float.win == nil then
        return
      end

      local updated = create_window_configurations()
      vim.api.nvim_win_set_config(background_float.win, updated.background)
      vim.api.nvim_win_set_config(header_float.win, updated.header)
      vim.api.nvim_win_set_config(body_float.win, updated.body)

      -- Update contents according to the updated width (re-center header)
      show_slide()
    end,
  })

  show_slide()
end

M.start_presentation({ bufnr = 10 })

return M
