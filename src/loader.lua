-- Relative require, implemented in Lua (no C stack games).
-- Search order per module: first relative to the requiring file's
-- directory, then relative to RETROLUNAR_LIB (default: cwd).
-- Cache key is the resolved file path in package.loaded, so the same
-- file required twice (even under different spellings) runs once.
do
  local _require = require
  local _loaded = package.loaded
  local _getinfo = debug.getinfo
  local _loadfile = loadfile
  local BASE = os.getenv('RETROLUNAR_LIB')
  if type(BASE) ~= 'string' or BASE == '' then BASE = '.' end
  local function is_rel(m)
    if m == '.' or m == '..' then return true end
    if m:sub(1, 2) == './' then return true end
    return m:sub(1, 3) == '../'
  end
  local function dirname(p)
    local d = p:match('^(.*)/[^/]+$')
    if d == nil or d == '' then return '.' end
    return d
  end
  local function resolve(base, req)
    local abs = base:sub(1, 1) == '/' or req:sub(1, 1) == '/'
    local joined = base .. '/' .. req
    if req:sub(1, 1) == '/' then joined = req end
    local parts = {}
    for tok in joined:gmatch('[^/]+') do
      if tok == '.' then
      elseif tok == '..' then
        if #parts > 0 and parts[#parts] ~= '..' then
          parts[#parts] = nil
        elseif not abs then
          parts[#parts + 1] = tok
        end
      else
        parts[#parts + 1] = (tok:gsub('%.', '/'))
      end
    end
    local out = table.concat(parts, '/')
    if abs then out = '/' .. out end
    if out == '' then out = '.' end
    return out
  end
  function require(mod, ...)
    if type(mod) ~= 'string' or not is_rel(mod) then
      return _require(mod, ...)
    end
    local dirs = {}
    local info = _getinfo(2, 'S')
    local src = info and info.source or nil
    if type(src) == 'string' and src:sub(1, 1) == '@' then
      dirs[#dirs + 1] = dirname(src:sub(2))
    end
    dirs[#dirs + 1] = BASE
    for _, d in ipairs(dirs) do
      local p = resolve(d, mod)
      for _, cand in ipairs({ p .. '.lua', p .. '/init.lua' }) do
        if _loaded[cand] ~= nil then return _loaded[cand] end
        local chunk, err = _loadfile(cand)
        if chunk then
          local res = chunk(mod)
          if res == nil then res = true end
          _loaded[cand] = res
          return res
        end
        local f = io.open(cand, 'r')
        if f then f:close() error(err, 2) end
      end
    end
    error("module '" .. mod .. "' not found", 2)
  end
end
