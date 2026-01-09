local B = {}

---@param buf? integer
---@return string
function B.get_text(buf)
  local lines = vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false)
  return table.concat(lines, "\n")
end

---@param opts { enabled_filetypes?: table<string, boolean> }
---@param buf? integer
---@return boolean
function B.is_enabled_buffer(opts, buf)
  buf = buf or 0

  if vim.bo[buf].buftype ~= "" then return false end
  if vim.bo[buf].modifiable == false then return false end

  local allow = opts.enabled_filetypes
  if allow and next(allow) ~= nil then
    local ft = vim.bo[buf].filetype
    return allow[ft] == true
  end

  return true
end

return B

