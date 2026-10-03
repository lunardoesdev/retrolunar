-- retrolunar module loading.
-- Two forms:
--   relative: require("./x"), require("../x") -- file relative to the
--     requiring file's directory, then RETROLUNAR_LIB (default: cwd).
--   pack@sys: require("hello@source") -- packages/hello/source.lua if
--     it exists, then system recipe fallbacks, then
--     packages/hello/generic.lua, else error. Explicit
--     pack@native resolves through DEFAULT_SYSTEM; it is not a system.
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
    -- Canonical key and name first: the unknown-system error below names
    -- the package that asked for it, which needs both.
    local key = key_stack[#key_stack] or (sys .. '@' .. (f or '?'))
    local keypack = key:match('^([^@]+)@')
    if t.name == nil and keypack ~= nil and not keypack:find('/') then
      t.name = keypack
    end
    local sysmod = sys .. '@generic'
    local st = _loaded[sysmod]
    local in_system = false
    for i = 1, #sys_stack do
      if sys_stack[i] == 'generic' then in_system = true break end
    end
    -- 'source' is a built-in pseudo-system: it stages sources and never
    -- compiles, so it has no recipe_fallbacks, no toolchain and no
    -- generic.lua of its own. Anything else must exist: swallowing a
    -- load failure here produced a recipe with no toolchain at all, which
    -- looked fine until it was built — the emitted script had no setup
    -- fragment to run, and a typo'd system name was accepted silently.
    if st == nil and sys ~= 'generic' and sys ~= 'source' and not in_system then
      local ok, res = pcall(require, sysmod)
      if not ok then
        error("system '" .. sys .. "' not found (needed by '" ..
              tostring(t.name or f or key) .. "'): " .. tostring(res), 2)
      end
      st = res
    end
    if type(st) == 'table' then t.system = st end
    -- Enqueue once per canonical key. Requires run before recipe(), so
    -- deps land first and queue order is already topological.
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
  local function recipe_path(pack, sys, rs)
    local function specific_path(name)
      for _, r in ipairs(rs) do
        local path = r .. '/' .. pack .. '/' .. name .. '.lua'
        if exists(path) then return path end
      end
    end
    local path = specific_path(sys)
    if path then return path end
    local ok, st = pcall(require, sys .. '@generic')
    if ok and type(st) == 'table' and type(st.recipe_fallbacks) == 'table' then
      for _, fallback in ipairs(st.recipe_fallbacks) do
        if type(fallback) == 'string' and fallback ~= '' then
          path = specific_path(fallback)
          if path then return path end
        end
      end
    end
    for _, r in ipairs(rs) do
      path = r .. '/' .. pack .. '/generic.lua'
      if exists(path) then return path end
    end
  end
  function require(mod, ...)
    if type(mod) ~= 'string' then return _require(mod, ...) end
    local pack, sys = mod:match('^([^@]+)@([^@]+)$')
    if pack and sys then
      if sys == 'native' then
        sys = _G.DEFAULT_SYSTEM
        if type(sys) ~= 'string' or sys == '' then
          error('retrolunar: DEFAULT_SYSTEM not set', 2)
        end
      end
      local canon = pack .. '@' .. sys
      if _loaded[canon] ~= nil then return _loaded[canon] end
      local rs = roots()
      local path = recipe_path(pack, sys, rs)
      if path then
        return run_with_sys(sys, path, canon, function()
          return load_cached(canon, path, canon)
        end)
      end
      error("module '" .. mod .. "' not found", 2)
    end
    if mod:match('^[^@%.%/]+$') then
      local isys = inherit_sys()
      local canon = mod .. '@' .. isys
      if _loaded[canon] ~= nil then return _loaded[canon] end
      local rs = roots()
      local path = recipe_path(mod, isys, rs)
      if path then
        return run_with_sys(isys, path, canon, function()
          return load_cached(canon, path, canon)
        end)
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
      -- collapse ./ and trailing /.: callers pass ./nest, ./packages.
      local joined = cwd .. '/' .. p
      local parts = {}
      for tok in joined:gmatch('[^/]+') do
        if tok == '.' then
        elseif tok == '..' then
          if #parts > 0 then parts[#parts] = nil end
        else
          parts[#parts + 1] = tok
        end
      end
      return '/' .. table.concat(parts, '/')
    end
    nestdir = abspath(nestdir or '.')
    pkgdir = abspath(pkgdir or '.')
    local native_system = _G.DEFAULT_SYSTEM
    if type(native_system) ~= 'string' or native_system == '' then
      error('retrolunar: DEFAULT_SYSTEM not set', 2)
    end
    local out = { '#!/bin/sh\nset -eu\n' }
    out[#out + 1] = 'NESTDIR=' .. sh_sq(nestdir) .. '\n'
    out[#out + 1] = 'PACKAGEDIR=' .. sh_sq(pkgdir) .. '\n'
    out[#out + 1] = 'mkdir -p "$NESTDIR"\n'
    out[#out + 1] = 'if ! command -v flock >/dev/null 2>&1; then\n'
    out[#out + 1] = '  echo "retrolunar: flock is required (install util-linux)" >&2\n'
    out[#out + 1] = '  exit 1\n'
    out[#out + 1] = 'fi\n'
    out[#out + 1] = 'exec 9>>"$NESTDIR/.retrolunar.lock"\n'
    out[#out + 1] = 'if ! flock -n 9; then\n'
    out[#out + 1] = '  echo "retrolunar: another build script is using NESTDIR: $NESTDIR" >&2\n'
    out[#out + 1] = '  exit 1\n'
    out[#out + 1] = 'fi\n'
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
        -- Companion files next to the system recipe (cmake toolchain,
        -- meson crossfile): any change must invalidate the stamp.
        local sysdir = e.system.dir
        if type(sysdir) == 'string' and sysdir ~= '' then
          local sd = sysdir:gsub('^%./', '')
          local dirref
          if sd:sub(1, 1) == '/' then dirref = sd
          else
            sd = sd:gsub('^packages/', '')
            dirref = '$PACKAGEDIR/' .. sd
          end
          out[#out + 1] = ' && [ ' .. stamp .. ' -nt ' .. dirref .. ' ]'
        end
      end
      out[#out + 1] = '; then\n'
      out[#out + 1] = '  echo "skip ' .. name .. '@' .. sys .. ' (fresh)"\n'
      out[#out + 1] = 'else\n'
      -- Dirs first so env values can reference them; env assignments use
      -- double quotes so $PREFIX/$OUT/$SYSDIR expand immediately instead
      -- of nesting one level too deep (cmake receives the literal text).
      out[#out + 1] = '  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")\n'
      out[#out + 1] = '  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")\n'
      out[#out + 1] = '  trap \'rm -rf "$WORK" "$OUT"\' EXIT\n'
      out[#out + 1] = '  cd "$WORK"\n'
      out[#out + 1] = '  PREFIX="$NESTDIR/' .. sys .. '"\n'
      out[#out + 1] = '  RECIPEDIR="$PACKAGEDIR/' .. name .. '"\n'
      if e.system and e.system.dir then
        local sd = e.system.dir:gsub('^%./', '')
        if sd:sub(1, 1) == '/' then
          out[#out + 1] = '  SYSDIR=' .. sh_sq(sd) .. '\n'
        else
          sd = sd:gsub('^packages/', '')
          out[#out + 1] = '  SYSDIR="$PACKAGEDIR/' .. sd .. '"\n'
        end
      else
        out[#out + 1] = '  SYSDIR="$PACKAGEDIR/' .. sys .. '"\n'
      end
      out[#out + 1] = '  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR"'
        .. ' RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR"'
        .. ' export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR\n'
      -- setup after dirs: the single shell fragment defining the whole
      -- environment (plain VAR="..." + export lines, may use
      -- $WORK/$OUT/$PREFIX/$SYSDIR/$RECIPEDIR and contain heredocs).
      local setup = e.system and e.system.setup or nil
      if type(setup) == 'string' and setup ~= '' then
        -- setup may contain heredocs: terminators must start at column 0.
        for raw in setup:gmatch('[^\n]*\n?') do
          local body = raw
          if body ~= '' then
            if body:sub(-1) ~= '\n' then body = body .. '\n' end
            if body:match('^%s*EOF%s*$') then
              body = 'EOF\n'
            else
              body = body:gsub('^  ', '', 1)
            end
            out[#out + 1] = body
          end
        end
      end
      out[#out + 1] = '  NATIVE_PREFIX="$NESTDIR"/' .. sh_sq(native_system) .. '\n'
      out[#out + 1] = '  PATH="$NATIVE_PREFIX/bin${PATH:+:$PATH}"\n'
      out[#out + 1] = '  LD_LIBRARY_PATH="$NATIVE_PREFIX/lib:$NATIVE_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
      out[#out + 1] = '  export NATIVE_PREFIX PATH LD_LIBRARY_PATH\n'
      local build = e.build
      if type(build) == 'string' then
        -- Recipe fields (version/git/tag/...) become shell vars so
        -- $version etc. work in build bodies. Strings only; skip
        -- tables (system), functions, and reserved build/file/dir keys.
        local fkeys = {}
        for k in pairs(e) do fkeys[#fkeys + 1] = k end
        table.sort(fkeys)
        for _, k in ipairs(fkeys) do
          if k ~= 'build' and k ~= 'file' and k ~= 'dir'
            and k ~= 'sys' and k ~= 'system' and k ~= 'name'
            and k:match('^[A-Za-z_][A-Za-z0-9_]*$') then
            local v = e[k]
            if type(v) == 'string' then
              out[#out + 1] = '      ' .. k .. '='
                .. "'" .. v:gsub("'", "'\\''") .. "'\n"
            end
          end
        end
        -- Same heredoc rule as setup: bare EOF terminates at column 0.
        for raw in build:gmatch('[^\n]*\n?') do
          local body = raw
          if body ~= '' then
            if body:sub(-1) ~= '\n' then body = body .. '\n' end
            if body:match('^%s*EOF%s*$') then
              body = 'EOF\n'
            else
              body = body:gsub('^  ', '', 1)
            end
            out[#out + 1] = body
          end
        end
      end
      -- Staged .pc, libtool .la and CMake package config files bake $OUT
      -- paths; $OUT is a per-block mktemp dir, so rewrite textually to
      -- $PREFIX. Without the cmake part, a config installed by one package
      -- points at a staging dir that no longer exists, and find_package in
      -- the next package fails. Pure sh string ops, no sed.
      out[#out + 1] = '  for _fix in "$OUT"/lib/pkgconfig/*.pc'
        .. ' "$OUT"/share/pkgconfig/*.pc "$OUT"/lib/*.la'
        .. ' "$OUT"/lib/cmake/*.cmake "$OUT"/lib/cmake/*/*.cmake'
        .. ' "$OUT"/lib/cmake/*/*/*.cmake'
        .. ' "$OUT"/share/cmake/*.cmake "$OUT"/share/cmake/*/*.cmake; do\n'
      out[#out + 1] = '    [ -f "$_fix" ] || continue\n'
      out[#out + 1] = '    while IFS= read -r _line || [ -n "$_line" ]; do\n'
      out[#out + 1] = '      case "$_line" in\n'
      out[#out + 1] = '        *"$OUT"*) printf "%s\\n" "$_line"'
        .. ' | awk -v o="$OUT" -v p="$PREFIX"'
        .. ' \'{ gsub(o, p); print }\'' .. ';;\n'
      out[#out + 1] = '        *) printf "%s\\n" "$_line";;\n'
      out[#out + 1] = '      esac\n'
      out[#out + 1] = '    done < "$_fix" > "$_fix.fixed"'
        .. ' && mv "$_fix.fixed" "$_fix"\n'
      out[#out + 1] = '  done\n'
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
