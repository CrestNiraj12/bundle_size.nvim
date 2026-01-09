local S = {}

---@class CompressSizeBufferState
---@field raw? integer
---@field gzip? integer
---@field brotli? integer
---@field result string
---@field tick? integer
---@field loading boolean

---@class CompressSizeCache
---@field by_buf table<integer, CompressSizeBufferState>

---@param cache CompressSizeCache
---@param buf integer
---@return CompressSizeBufferState
function S.get(cache, buf)
  local s = cache.by_buf[buf]
  if not s then
    s = {
      raw = nil,
      gzip = nil,
      brotli = nil,
      result = "",
      tick = nil,
      loading = false,
    }
    cache.by_buf[buf] = s
  end
  return s
end

---@param cache CompressSizeCache
---@param buf integer
function S.clear(cache, buf)
  cache.by_buf[buf] = nil
end

---@param cache CompressSizeCache
function S.clear_all(cache)
  cache.by_buf = {}
end

return S

