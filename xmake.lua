set_project("retrolunar")

target("lua")
set_kind("static")
add_files("lua/src/*.c|lua.c|luac.c")
add_defines("LUA_USE_POSIX")
add_includedirs("lua/src", {public = true})
