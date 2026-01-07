local C = {}

local function run(cmd, input, cb)
  vim.system(cmd, { stdin = input, text = false }, function(obj)
    cb(obj)
  end)
end

function C.gzip_size(text, cb)
  if vim.fn.executable("gzip") ~= 1 then
    return cb(nil)
  end

  run({ "gzip", "-c" }, text, function(obj)
    if obj.code ~= 0 then return cb(nil) end
    cb(#(obj.stdout or ""))
  end)
end

function C.brotli_size(text, cb, quality)
  if vim.fn.executable("brotli") ~= 1 then
    return cb(nil)
  end

  local q = tostring(quality or 11)
  run({ "brotli", "-f", "-q", q, "-c" }, text, function(obj)
    if obj.code ~= 0 then return cb(nil) end
    cb(#(obj.stdout or ""))
  end)
end

return C
