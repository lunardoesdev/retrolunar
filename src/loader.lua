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

  local function dirname(p)
    local d = p:match('^(.*)/[^/]+$')
    if d == nil or d == '' then return '.' end
    return d
  end
  local function is_rel(m)
    if m == '.' or m == '..' then return true end
    if m:sub(1, 2) == './' then return true end
    return m:sub(1, 3) == '../'
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

  -- System + file + key stacks: top = module currently loading.
  -- key_stack holds the canonical require key (pack@sys or resolved
  -- relative path) so recipe() enqueues under the right identity.
  local sys_stack = {}
  local file_stack = {}
  local key_stack = {}
  -- Build queue: recipe() tables in first-execution order (leaves first,
  -- since requires run before the recipe() call at file end).
  local queue = {}
  local queued = {}
  local function current_sys()
    if #sys_stack > 0 then return sys_stack[#sys_stack] end
    local d = _G.DEFAULT_SYSTEM
    if type(d) ~= 'string' or d == '' then
      error('retrolunar: DEFAULT_SYSTEM not set', 3)
    end
    return d
  end
  local function current_file() return file_stack[#file_stack] end
  local function run_with_sys(sys, file, key, fn)
    sys_stack[#sys_stack + 1] = sys
    file_stack[#file_stack + 1] = file
    key_stack[#key_stack + 1] = key
    local saved = _G.SYSTEM
    _G.SYSTEM = sys
    local ok, res = pcall(fn)
    if saved == nil then _G.SYSTEM = nil else _G.SYSTEM = saved end
    key_stack[#key_stack] = nil
    file_stack[#file_stack] = nil
    sys_stack[#sys_stack] = nil
    if not ok then error(res, 0) end
    return res
  end

  -- System to inherit for bare/relative requires: inside a system file
  -- (loaded as <sys>@generic, stack top "generic") there is no parent
  -- package system, so use the C predefined DEFAULT_SYSTEM. Elsewhere
  -- inherit the requiring module's system. Explicit pack@sys unaffected.
  local function inherit_sys()
    for i = 1, #sys_stack do
      if sys_stack[i] == 'generic' then
        local d = _G.DEFAULT_SYSTEM
        if type(d) ~= 'string' or d == '' then
          error('retrolunar: DEFAULT_SYSTEM not set', 3)
        end
        return d
      end
    end
    return current_sys()
  end
  function system(t)
    if type(t) ~= 'table' then error('system() needs a table', 2) end
    local f = current_file()
    if f ~= nil then
      t.file = f
      t.dir = dirname(f)
    end
    print('system(' .. dump(t) .. ')')
    return t
  end
  function recipe(t)
    if type(t) ~= 'table' then error('recipe() needs a table', 2) end
    local f = current_file()
    if f ~= nil then
      t.file = f
      t.dir = dirname(f)
    end
    local sys = sys_stack[#sys_stack]
    if sys == nil then sys = current_sys() end
    t.sys = sys
    local sysmod = sys .. '@generic'
    local st = _loaded[sysmod]
    local in_system = false
    for i = 1, #sys_stack do
      if sys_stack[i] == 'generic' then in_system = true break end
    end
    if st == nil and sys ~= 'generic' and not in_system then
      local ok, res = pcall(require, sysmod)
      if ok then st = res end
    end
    if type(st) == 'table' then t.system = st end
    -- Enqueue once per canonical key. Requires run before recipe(), so
    -- deps land first and queue order is already topological.
    local key = key_stack[#key_stack] or (sys .. '@' .. (f or '?'))
    if queued[key] then error("recipe() duplicate entry for " .. key, 2) end
    queued[key] = true
    queue[#queue + 1] = t
    print('recipe(' .. dump(t) .. ')')
    return t
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
          return run_with_sys(sys, specific, mod, function()
            return load_cached(mod, specific, mod)
          end)
        end
      end
      for _, r in ipairs(rs) do
        local generic = r .. '/packages/' .. pack .. '/generic.lua'
        if exists(generic) then
          return run_with_sys(sys, generic, mod, function()
            return load_cached(mod, generic, mod)
          end)
        end
      end
      error("module '" .. mod .. "' not found", 2)
    end
    if mod:match('^[^@%.%/]+$') then
      local isys = inherit_sys()
      local canon = mod .. '@' .. isys
      if _loaded[canon] ~= nil then return _loaded[canon] end
      local rs = roots()
      for _, r in ipairs(rs) do
        local specific = r .. '/packages/' .. mod .. '/' .. isys .. '.lua'
        if exists(specific) then
          return run_with_sys(isys, specific, canon, function()
            return load_cached(canon, specific, canon)
          end)
        end
      end
      for _, r in ipairs(rs) do
        local generic = r .. '/packages/' .. mod .. '/generic.lua'
        if exists(generic) then
          return run_with_sys(isys, generic, canon, function()
            return load_cached(canon, generic, canon)
          end)
        end
      end
      -- No package file: fall through (stdlib like string, io).
    end
    if not is_rel(mod) then
      return _require(mod, ...)
    end
    local dirs = {}
    local lvl = 2
    while true do
      local info = _getinfo(lvl, 'Sf')
      if not info then break end
      if info.func ~= require then
        local src = info.source
        if type(src) == 'string' and src:sub(1, 1) == '@' then
          dirs[#dirs + 1] = dirname(src:sub(2))
        end
        break
      end
      lvl = lvl + 1
    end
    dirs[#dirs + 1] = BASE
    local rsys = inherit_sys()
    for _, d in ipairs(dirs) do
      local p = resolve(d, mod)
      for _, cand in ipairs({ p .. '.lua', p .. '/init.lua' }) do
        if _loaded[cand] ~= nil then return _loaded[cand] end
        local chunk, err = _loadfile(cand)
        if chunk then
          return run_with_sys(rsys, cand, cand, function()
            local res = chunk(mod)
            if res == nil then res = true end
            _loaded[cand] = res
            return res
          end)
        end
        local f = io.open(cand, 'r')
        if f then f:close() error(err, 2) end
      end
    end
    error("module '" .. mod .. "' not found", 2)
  end
  function require_system() return current_sys() end
  function require_queue()
    local snap = {}
    for i, t in ipairs(queue) do snap[i] = t end
    return snap
  end
end
