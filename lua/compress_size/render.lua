local F = require("compress_size.format")

local R = {}

---@class CompressSizeRenderOpts
---@field show { raw: boolean, gzip: boolean, brotli: boolean }
---@field separator string

---@param opts CompressSizeRenderOpts
---@param s CompressSizeBufferState
---@return string
function R.build_result(opts, s)
  local parts = {}

  if opts.show.raw then
    table.insert(parts, "raw " .. (s.raw and F.bytes(s.raw) or "?"))
  end
  if opts.show.gzip then
    table.insert(parts, "gz " .. (s.gzip and F.bytes(s.gzip) or "?"))
  end
  if opts.show.brotli then
    table.insert(parts, "br " .. (s.brotli and F.bytes(s.brotli) or "?"))
  end

  -- Show the last known values, but append a subtle loading indicator
  -- while async compression sizes are being recomputed.
  local result = table.concat(parts, " " .. opts.separator .. " ")
  if s.loading then
    if result == "" then
      return "CompressSize: Refreshing…"
    end
    return result .. " " .. opts.separator .. " Refreshing…"
  end

  return result
end

return R

