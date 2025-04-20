vim.api.nvim_create_user_command("PresentStart", function(opts)
  package.loaded["present"] = nil

  local bufnr = nil

  if opts.fargs and #opts.fargs > 0 then
    bufnr = tonumber(opts.fargs[1])

    -- Check if valid type was given
    if bufnr == nil then
      print("Error: invalid argument type, buffer number expected")
      return
    end

    -- Check if buffer exists
    local bufs = vim.api.nvim_list_bufs()
    local buffer_exists = false
    for _, buffer_id in ipairs(bufs) do
      if buffer_id == bufnr then
        buffer_exists = true
        break
      end
    end

    if not buffer_exists then
      print("Error: invalid argument, buffer", bufnr, "does not exist")
      return
    end
  else
    bufnr = vim.api.nvim_get_current_buf()
  end

  require("present").start_presentation({ bufnr = bufnr })
end, {
  nargs = "?",
  complete = "buffer",
})
