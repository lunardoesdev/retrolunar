-- retrolunar module loading.
-- Two forms:
--   relative: require("./x"), require("../x") -- file relative to the
--     requiring file's directory, then RETROLUNAR_LIB (default: cwd).
--   pack@sys: require("hello@source") -- packages/hello/source.lua if
--     it exists, else packages/hello/generic.lua, else error.
-- Both cache by resolved path in package.loaded so repeats run no code.
do
  local _require = require
  local _loaded = package.loaded
  local _getinfo = debug.getinfo
  local _loadfile = loadfile
  local BASE = os.getenv('RETROLUNAR_LIB')
  if type(BASE) ~= 'string' or BASE == '' then BASE = '.' end

  local function dump(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == 'string' then return string.format('%q', v) end
    if t ~= 'table' then return tostring(v) end
    if depth > 4 then return '{...}' end
    local parts = {}
    for k, val in pairs(v) do
      local key = type(k) == 'string' and k or ('[' .. tostring(k) .. ']')
      parts[#parts + 1] = key .. ' = ' .. dump(val, depth + 1)
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
  end

  function system(t)
    print('system(' .. dump(t) .. ')')
    return t
  end

  function package(t)
    print('package(' .. dump(t) .. ')')
    return t
  end

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
  local function exists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
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
  local function roots()
    if BASE == '.' then return { '.' } end
    return { BASE, '.' }
  end
  local function load_cached(key, path, mod)
    if _loaded[key] ~= nil then return _loaded[key] end
    local chunk, err = _loadfile(path)
    if not chunk then error(err, 3) end
    local res = chunk(mod)
    if res == nil then res = true end
    _loaded[key] = res
    return res
  end
  function require(mod, ...)
    if type(mod) ~= 'string' then return _require(mod, ...) end
    local pack, sys = mod:match('^([^@]+)@([^@]+)$')
    if pack and sys then
      if _loaded[mod] ~= nil then return _loaded[mod] end
      local rs = roots()
      for _, r in ipairs(rs) do
        local specific = r .. '/packages/' .. pack .. '/' .. sys .. '.lua'
        if exists(specific) then
          return load_cached(mod, specific, mod)
        end
      end
      for _, r in ipairs(rs) do
        local generic = r .. '/packages/' .. pack .. '/generic.lua'
        if exists(generic) then
          return load_cached(mod, generic, mod)
        end
      end
      error("module '" .. mod .. "' not found", 2)
    end
    if not is_rel(mod) then
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
