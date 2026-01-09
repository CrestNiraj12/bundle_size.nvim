local M = {}

local buf = require("compress_size.buf")
local compute = require("compress_size.compute")
local redraw = require("compress_size.redraw")
local render = require("compress_size.render")
local state = require("compress_size.state")

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
M._redraw = setmetatable({}, { __index = redraw })

local function buf_state(b)
  return state.get(M.cache, b)
end

local function clear_buf_state(b)
  state.clear(M.cache, b)
end


local function build_result(s)
  return render.build_result({ show = M.opts.show, separator = M.opts.separator }, s)
end

local function request_redraw()
  M._redraw:request()
end

function M.refresh()
  local gen = M._gen

  if vim.in_fast_event() then
    vim.schedule(M.refresh)
    return
  end

  local cur_buf = vim.api.nvim_get_current_buf()

  if M.opts.enabled == false then
    local s = buf_state(cur_buf)
    if s.result ~= "" then
      s.result = ""
      s.tick = nil
      request_redraw()
    end
    return
  end

  if not buf.is_enabled_buffer(M.opts, cur_buf) then
    clear_buf_state(cur_buf)
    return
  end

  local s = buf_state(cur_buf)
  local tick = vim.b[cur_buf].changedtick

  -- If the buffer hasn't changed and we're not currently waiting on any sizes,
  -- keep the existing (already computed) display.
  if s.tick == tick and s.result ~= "" and not s.loading then
    return
  end

  s.tick = tick

  local text = buf.get_text(cur_buf)
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

  local target_buf = cur_buf

  if M.opts.show.gzip then
    compute.gzip_size(text, function(gz)
      vim.schedule(function()
        if M._gen ~= gen then return end
        if M.opts.enabled == false then return end

        if not vim.api.nvim_buf_is_valid(target_buf) then return end
        if target_buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[target_buf].changedtick then return end

        local st = buf_state(target_buf)
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

        if not vim.api.nvim_buf_is_valid(target_buf) then return end
        if target_buf ~= vim.api.nvim_get_current_buf() then return end
        if tick ~= vim.b[target_buf].changedtick then return end

        local st = buf_state(target_buf)
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
  local group = vim.api.nvim_create_augroup("CompressSize", { clear = true })

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

  vim.api.nvim_create_user_command("CompressSizeRefresh", function()
    local cur_buf = vim.api.nvim_get_current_buf()
    local s = buf_state(cur_buf)

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

  vim.api.nvim_create_user_command("CompressSizeToggle", function()
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

      if not vim.g.compress_size_silent_toggle then
        pcall(vim.notify, "CompressSize: disabled", vim.log.levels.INFO)
      end
      return
    end

    -- Enable
    M.opts.enabled = true

    local cur_buf = vim.api.nvim_get_current_buf()
    local s = buf_state(cur_buf)

    -- Force a refresh even if unchangedtick didn't change.
    s.tick = nil

    -- Show loading while recomputing.
    s.loading = true
    local r = build_result(s)
    if r ~= s.result then
      s.result = r
      request_redraw()
    end

    if not vim.g.compress_size_silent_toggle then
      pcall(vim.notify, "CompressSize: enabled", vim.log.levels.INFO)
    end

    vim.schedule(M.refresh)
  end, {})

  vim.schedule(M.refresh)
end

function M.status()
  local cur_buf = vim.api.nvim_get_current_buf()
  local s = M.cache.by_buf[cur_buf]
  return (s and s.result) or ""
end

return M
