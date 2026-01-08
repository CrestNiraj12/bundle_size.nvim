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
  by_buf = {},
}

M._gen = 0
M._timer = nil
M._redraw_timer = nil

local function buf_state(buf)
  local s = M.cache.by_buf[buf]
  if not s then
    s = {
      raw = nil,
      gzip = nil,
      brotli = nil,
      result = "",
      tick = nil,
      loading = false,
    }
    M.cache.by_buf[buf] = s
  end
  return s
end

local function clear_buf_state(buf)
  M.cache.by_buf[buf] = nil
end

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

local function build_result(s)
  local parts = {}

  if M.opts.show.raw then
    table.insert(parts, "raw " .. (s.raw and format_bytes(s.raw) or "?"))
  end
  if M.opts.show.gzip then
    table.insert(parts, "gz " .. (s.gzip and format_bytes(s.gzip) or "?"))
  end
  if M.opts.show.brotli then
    table.insert(parts, "br " .. (s.brotli and format_bytes(s.brotli) or "?"))
  end

  -- Show the last known values, but append a subtle loading indicator
  -- while async compression sizes are being recomputed.
  local result = table.concat(parts, " " .. M.opts.separator .. " ")
  if s.loading then
    if result == "" then
      return "BundleSize: Refreshing…"
    end
    return result .. " " .. M.opts.separator .. " Refreshing…"
  end

  return result
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
  local gen = M._gen

  if vim.in_fast_event() then
    vim.schedule(M.refresh)
    return
  end

  local buf = vim.api.nvim_get_current_buf()

  if M.opts.enabled == false then
    local s = buf_state(buf)
    if s.result ~= "" then
      s.result = ""
      s.tick = nil
      request_redraw()
    end
    return
  end

  if not is_enabled_buffer(buf) then
    clear_buf_state(buf)
    return
  end

  local s = buf_state(buf)
  local tick = vim.b[buf].changedtick

  -- If the buffer hasn't changed and we're not currently waiting on any sizes,
  -- keep the existing (already computed) display.
  if s.tick == tick and s.result ~= "" and not s.loading then
    return
  end

  s.tick = tick

  local text = get_buf_text(buf)
  local raw = #text

  if raw > (M.opts.max_file_size_kb * 1024) then
    s.raw, s.gzip, s.brotli = raw, nil, nil
    if s.result ~= "raw (too big)" then
      s.result = "raw (too big)"
      request_redraw()
    end
    return
  end

  s.raw = raw

  -- Enter loading state while async sizes are being recomputed.
  local pending = 0
  if M.opts.show.gzip then
    pending = pending + 1
    s.gzip = nil
  end
  if M.opts.show.brotli then
    pending = pending + 1
    s.brotli = nil
  end

  s.loading = pending > 0

  local new_result = build_result(s)
  if new_result ~= s.result then
    s.result = new_result
    request_redraw()
  end

  local function done_one(st)
    pending = pending - 1
    if pending <= 0 then
      st.loading = false
    end

    local r = build_result(st)
    if r ~= st.result then
      st.result = r
      request_redraw()
    end
  end

  if M.opts.show.gzip then
    compute.gzip_size(text, function(gz)
      vim.schedule(function()
        if M._gen ~= gen then return end
        if M.opts.enabled == false then return end

        if not vim.api.nvim_buf_is_valid(buf) then return end
        if buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[buf].changedtick then return end

        local st = buf_state(buf)
        st.gzip = gz
        done_one(st)
      end)
    end)
  end

  if M.opts.show.brotli then
    compute.brotli_size(text, function(br)
      vim.schedule(function()
        if M._gen ~= gen then return end
        if M.opts.enabled == false then return end

        if not vim.api.nvim_buf_is_valid(buf) then return end
        if buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[buf].changedtick then return end

        local st = buf_state(buf)
        st.brotli = br
        done_one(st)
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

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      clear_buf_state(args.buf)
    end,
  })

  vim.api.nvim_create_user_command("BundleSizeRefresh", function()
    local buf = vim.api.nvim_get_current_buf()
    local s = buf_state(buf)

    -- Force a refresh even if unchangedtick didn't change.
    s.tick = nil

    -- Keep last known values, but show loading while recomputing.
    s.loading = true
    local r = build_result(s)
    if r ~= s.result then
      s.result = r
      request_redraw()
    end

    vim.schedule(M.refresh)
  end, {})

  vim.api.nvim_create_user_command("BundleSizeToggle", function()
    M._gen = M._gen + 1

    -- Disable
    if M.opts.enabled ~= false then
      M.opts.enabled = false

      if M._timer then
        M._timer:stop()
        M._timer:close()
        M._timer = nil
      end

      -- Clear all cached state so status() returns empty and nothing is shown.
      M.cache.by_buf = {}
      request_redraw()

      if not vim.g.bundle_size_silent_toggle then
        pcall(vim.notify, "BundleSize: disabled", vim.log.levels.INFO)
      end
      return
    end

    -- Enable
    M.opts.enabled = true

    local buf = vim.api.nvim_get_current_buf()
    local s = buf_state(buf)

    -- Force a refresh even if unchangedtick didn't change.
    s.tick = nil

    -- Show loading while recomputing.
    s.loading = true
    local r = build_result(s)
    if r ~= s.result then
      s.result = r
      request_redraw()
    end

    if not vim.g.bundle_size_silent_toggle then
      pcall(vim.notify, "BundleSize: enabled", vim.log.levels.INFO)
    end

    vim.schedule(M.refresh)
  end, {})

  vim.schedule(M.refresh)
end

function M.status()
  local buf = vim.api.nvim_get_current_buf()
  local s = M.cache.by_buf[buf]
  return (s and s.result) or ""
end

return M
