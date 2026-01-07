local M = {}
local compute = require("bundle_size.compute")

M.opts = {
  enabled = true,
  show = { raw = true, gzip = true, brotli = true },
  delay_ms = 200,
  brotli_quality = 11,
  max_file_size_kb = 1024,
  separator = "|",
  enabled_filetypes = {
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
    css = true,
    scss = true,
    html = true,
    json = true,
    lua = true,
  },
}

M.cache = {
  raw = nil,
  gzip = nil,
  brotli = nil,
  result = "raw ?",
  last_tick = {},
}

M._timer = nil
M._redraw_timer = nil

local function format_bytes(n)
  local byte_size = 1024
  if n < byte_size then return tostring(n) .. "b" end
  if n < byte_size * byte_size then return string.format("%.1fK", n / byte_size) end
  return string.format("%.2fM", n / (byte_size * byte_size))
end

local function get_buf_text(buf)
  local lines = vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false)
  return table.concat(lines, "\n")
end

local function is_enabled_buffer(buf)
  buf = buf or 0
  if vim.bo[buf].buftype ~= "" then return false end
  if vim.bo[buf].modifiable == false then return false end

  local ft = vim.bo[buf].filetype
  local allow = M.opts.enabled_filetypes
  if allow and next(allow) ~= nil then
    return allow[ft] == true
  end

  return true
end

local function build_result()
  local parts = {}

  if M.opts.show.raw then
    table.insert(parts, "raw " .. (M.cache.raw and format_bytes(M.cache.raw) or "?"))
  end

  if M.opts.show.gzip then
    table.insert(parts, "gz " .. (M.cache.gzip and format_bytes(M.cache.gzip) or "?"))
  end

  if M.opts.show.brotli then
    table.insert(parts, "br " .. (M.cache.brotli and format_bytes(M.cache.brotli) or "?"))
  end

  return table.concat(parts, " " .. M.opts.separator .. " ")
end

local function request_redraw()
  if M._redraw_timer then return end

  M._redraw_timer = vim.uv.new_timer()
  M._redraw_timer:start(50, 0, function()
    M._redraw_timer:stop()
    M._redraw_timer:close()
    M._redraw_timer = nil
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end

function M.refresh()
  if vim.in_fast_event() then
    vim.schedule(M.refresh)
    return
  end

  if M.opts.enabled == false then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  if not is_enabled_buffer(buf) then
    M.cache.raw = nil
    M.cache.gzip = nil
    M.cache.brotli = nil
    M.cache.last_tick[buf] = nil
    if M.cache.result ~= "" then
      M.cache.result = ""
      request_redraw()
    end
    return
  end

  local tick = vim.b[buf].changedtick
  if M.cache.last_tick[buf] == tick then
    return
  end

  M.cache.last_tick[buf] = tick
  local text = get_buf_text(buf)
  local raw = #text
  if raw > (M.opts.max_file_size_kb * 1024) then
    M.cache.raw = raw
    M.cache.gzip = nil
    M.cache.brotli = nil
    if M.cache.result ~= "raw (too big)" then
      M.cache.result = "raw (too big)"
      request_redraw()
    end
    return
  end

  M.cache.raw = raw
  M.cache.gzip = nil
  M.cache.brotli = nil
  local new_result = build_result()
  if new_result ~= M.cache.result then
    M.cache.result = new_result
    request_redraw()
  end

  if M.opts.show.gzip then
    compute.gzip_size(text, function(gz)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[buf].changedtick then return end

        M.cache.gzip = gz
        local result = build_result()
        if result ~= M.cache.result then
          M.cache.result = result
          request_redraw()
        end
      end)
    end)
  end

  if M.opts.show.brotli then
    compute.brotli_size(text, function(br)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[buf].changedtick then return end

        M.cache.brotli = br
        local result = build_result()
        if result ~= M.cache.result then
          M.cache.result = result
          request_redraw()
        end
      end)
    end, M.opts.brotli_quality)
  end
end

function M.refresh_debounced()
  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end

  M._timer = vim.uv.new_timer()
  M._timer:start(M.opts.delay_ms, 0, function()
    vim.schedule(M.refresh)
  end)
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  local group = vim.api.nvim_create_augroup("BundleSize", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    callback = function()
      vim.schedule(M.refresh)
    end
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = M.refresh_debounced
  })

  vim.api.nvim_create_user_command("BundleSizeRefresh", function()
    vim.schedule(M.refresh)
  end, {})

  vim.api.nvim_create_user_command("BundleSizeToggle", function()
    M.opts.enabled = (M.opts.enabled ~= false) and false or true
    if not M.opts.enabled then
      M.cache.result = ""
      request_redraw()
    else
      vim.schedule(M.refresh)
    end
  end, {})

  vim.schedule(M.refresh)
end

function M.status()
  return M.cache.result or ""
end

return M
