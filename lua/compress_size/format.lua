local F = {}

---@param n integer
---@return string
function F.bytes(n)
  local byte_size = 1024
  if n < byte_size then return tostring(n) .. "b" end
  if n < byte_size * byte_size then return string.format("%.1fK", n / byte_size) end
  return string.format("%.2fM", n / (byte_size * byte_size))
end

return F

