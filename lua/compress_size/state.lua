local S = {}

---@class BundleSizeBufferState
---@field raw? integer
---@field gzip? integer
---@field brotli? integer
---@field result string
---@field tick? integer
---@field loading boolean

---@class BundleSizeCache
---@field by_buf table<integer, BundleSizeBufferState>

---@param cache BundleSizeCache
---@param buf integer
---@return BundleSizeBufferState
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

---@param cache BundleSizeCache
---@param buf integer
function S.clear(cache, buf)
  cache.by_buf[buf] = nil
end

---@param cache BundleSizeCache
function S.clear_all(cache)
  cache.by_buf = {}
end

return S

