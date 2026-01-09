local D = {}

---@class BundleSizeRedraw
---@field _timer? uv.uv_timer_t

---@param self BundleSizeRedraw
function D:request()
  if self._timer then return end

  self._timer = vim.uv.new_timer()
  self._timer:start(50, 0, function()
    self._timer:stop()
    self._timer:close()
    self._timer = nil
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end)
end

return D

