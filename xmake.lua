set_project("retrolunar")

target("lua")
set_kind("static")
add_files("lua/src/*.c|lua.c|luac.c")
add_defines("LUA_USE_POSIX", {public = true})
add_includedirs("lua/src", {public = true})
add_syslinks("m", {public = true})

target("retrolunar")
add_files("src/*.c")
add_deps("lua")