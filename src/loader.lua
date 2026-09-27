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
  -- Packages dir is fixed at load time (loader runs once at startup),
  -- from install's boot global, else the env, else BASE.
  local _pd = _G.RETROLUNAR_PKGS_BOOT or os.getenv('RETROLUNAR_PACKAGES')
  local PKGDIR = (type(_pd) == 'string' and _pd ~= '') and _pd or BASE
  _G.RETROLUNAR_PKGS_BOOT = PKGDIR
  local function roots()
    if PKGDIR == '.' and BASE == '.' then return { '.' } end
    if PKGDIR == BASE then return { BASE, '.' } end
    return { PKGDIR, BASE, '.' }
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
    local keypack = key:match('^([^@]+)@')
    if t.name == nil and keypack ~= nil and not keypack:find('/') then
      t.name = keypack
    end
    if queued[key] then error("recipe() duplicate entry for " .. key, 2) end
    queued[key] = true
    queue[#queue + 1] = t
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
        local specific = r .. '/' .. pack .. '/' .. sys .. '.lua'
        if exists(specific) then
          return run_with_sys(sys, specific, mod, function()
            return load_cached(mod, specific, mod)
          end)
        end
      end
      for _, r in ipairs(rs) do
        local generic = r .. '/' .. pack .. '/generic.lua'
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
        local specific = r .. '/' .. mod .. '/' .. isys .. '.lua'
        if exists(specific) then
          return run_with_sys(isys, specific, canon, function()
            return load_cached(canon, specific, canon)
          end)
        end
      end
      for _, r in ipairs(rs) do
        local generic = r .. '/' .. mod .. '/generic.lua'
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
  -- Emit the idempotent POSIX sh install script for the current queue.
  -- Uses $NESTDIR/$RECIPEDIR/$PACKAGEDIR at script runtime; OUT/WORK are
  -- per-package shell locals. Env values come from entry.system.env.
  local function sh_sq(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
  end
  function require_script(nestdir, pkgdir)
    local function abspath(p)
      if p:sub(1, 1) == '/' then return p end
      local h = io.popen('pwd')
      local cwd = h and h:read('*l') or '.'
      if h then h:close() end
      return cwd .. '/' .. p
    end
    nestdir = abspath(nestdir or '.')
    pkgdir = abspath(pkgdir or '.')
    local out = { '#!/bin/sh\nset -eu\n' }
    out[#out + 1] = 'NESTDIR=' .. sh_sq(nestdir) .. '\n'
    out[#out + 1] = 'PACKAGEDIR=' .. sh_sq(pkgdir) .. '\n'
    out[#out + 1] = 'mkdir -p "$NESTDIR/tmp"\n'
    for _, e in ipairs(queue) do
      local name = e.name or e.file or 'unknown'
      local sys = e.sys or 'unknown'
      out[#out + 1] = '# --- ' .. name .. '@' .. sys .. ' ---\n'
      local stamp = '$NESTDIR/' .. sys .. '/.retrolunar-' .. name
      local recipe_src = '$RECIPEDIR/' .. name .. '.lua'
      if e.file then
        local rf = e.file:gsub('^%./', '')
        if rf:sub(1, 1) == '/' then
          recipe_src = rf
        else
          rf = rf:gsub('^packages/', '')
          recipe_src = '$PACKAGEDIR/' .. rf
        end
      end
      out[#out + 1] = 'if [ -f ' .. stamp .. ' ]'
      out[#out + 1] = ' && [ ' .. stamp .. ' -nt ' .. recipe_src .. ' ]'
      if e.system and e.system.file then
        local sf = e.system.file:gsub('^%./', '')
        local sysref
        if sf:sub(1, 1) == '/' then sysref = sf
        else
          sf = sf:gsub('^packages/', '')
          sysref = '$PACKAGEDIR/' .. sf
        end
        out[#out + 1] = ' && [ ' .. stamp .. ' -nt ' .. sysref .. ' ]'
      end
      out[#out + 1] = '; then\n'
      out[#out + 1] = '  echo "skip ' .. name .. '@' .. sys .. ' (fresh)"\n'
      out[#out + 1] = 'else\n'
      local env = e.system and e.system.env or nil
      if type(env) == 'table' then
        local names = {}
        for k in pairs(env) do names[#names + 1] = k end
        table.sort(names)
        if #names > 0 then
          local set = {}
          for _, k in ipairs(names) do
            set[#set + 1] = k .. '=' .. sh_sq(env[k])
          end
          out[#out + 1] = '  ' .. table.concat(set, ' ')
            .. ' export ' .. table.concat(names, ' ') .. '\n'
        end
      end
      out[#out + 1] = '  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")\n'
      out[#out + 1] = '  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")\n'
      out[#out + 1] = '  trap \'rm -rf "$WORK" "$OUT"\' EXIT\n'
      out[#out + 1] = '  cd "$WORK"\n'
      out[#out + 1] = '  PREFIX="$NESTDIR/' .. sys .. '"\n'
      out[#out + 1] = '  RECIPEDIR="$PACKAGEDIR/' .. name .. '"\n'
      out[#out + 1] = '  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR"'
        .. ' RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX"'
        .. ' export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX\n'
      local build = e.build
      if type(build) == 'string' then
        for raw in build:gmatch('[^\n]*\n?') do
          local body = raw
          if body ~= '' then
            if body:sub(-1) ~= '\n' then body = body .. '\n' end
            out[#out + 1] = '  ' .. body
          end
        end
      end
      out[#out + 1] = '  mkdir -p "$NESTDIR/' .. sys .. '"\n'
      out[#out + 1] = '  cp -rf "$OUT"/. "$NESTDIR/' .. sys .. '/"\n'
      out[#out + 1] = '  touch ' .. stamp .. '\n'
      out[#out + 1] = '  rm -rf "$WORK" "$OUT"\n'
      out[#out + 1] = '  trap - EXIT\n'
      out[#out + 1] = 'fi\n'
    end
    return table.concat(out)
  end
end
