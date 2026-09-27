project('retrolunar', 'c',
  version : '0.1',
  default_options : ['c_std=gnu99', 'warning_level=2'],
)
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : true)

lua_sources = files(
  'lua-5.5.1/src/lapi.c',
  'lua-5.5.1/src/lcode.c',
  'lua-5.5.1/src/lctype.c',
  'lua-5.5.1/src/ldebug.c',
  'lua-5.5.1/src/ldo.c',
  'lua-5.5.1/src/ldump.c',
  'lua-5.5.1/src/lfunc.c',
  'lua-5.5.1/src/lgc.c',
  'lua-5.5.1/src/llex.c',
  'lua-5.5.1/src/lmem.c',
  'lua-5.5.1/src/lobject.c',
  'lua-5.5.1/src/lopcodes.c',
  'lua-5.5.1/src/lparser.c',
  'lua-5.5.1/src/lstate.c',
  'lua-5.5.1/src/lstring.c',
  'lua-5.5.1/src/ltable.c',
  'lua-5.5.1/src/ltm.c',
  'lua-5.5.1/src/lundump.c',
  'lua-5.5.1/src/lvm.c',
  'lua-5.5.1/src/lzio.c',
  'lua-5.5.1/src/lauxlib.c',
  'lua-5.5.1/src/lbaselib.c',
  'lua-5.5.1/src/lcorolib.c',
  'lua-5.5.1/src/ldblib.c',
  'lua-5.5.1/src/liolib.c',
  'lua-5.5.1/src/lmathlib.c',
  'lua-5.5.1/src/loadlib.c',
  'lua-5.5.1/src/loslib.c',
  'lua-5.5.1/src/lstrlib.c',
  'lua-5.5.1/src/ltablib.c',
  'lua-5.5.1/src/lutf8lib.c',
  'lua-5.5.1/src/linit.c',
)
lua_lib = static_library('lua',
  lua_sources,
  c_args : '-DLUA_USE_POSIX',
  install : true,
)

lua_dep = declare_dependency(
  link_with : lua_lib,
  include_directories : include_directories('lua-5.5.1/src'),
  compile_args : '-DLUA_USE_POSIX',
  dependencies : m_dep,
)

loader_c = custom_target('loader_lua',
  input : 'src/loader.lua',
  output : 'loader_lua.c',
  depend_files : 'src/embed.py',
  command : [find_program('python3'), meson.project_source_root() / 'src' / 'embed.py', '@INPUT@', '@OUTPUT@'],
)

executable('retrolunar',
  ['src/main.c', loader_c],
  dependencies : lua_dep,
  install : true,
)
