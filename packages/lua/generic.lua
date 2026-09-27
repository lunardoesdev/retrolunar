require("lua@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lua/* .
        # Upstream Makefile is linux/host-only: build objects with $CC,
        # then archive + install the headers by hand.
        mkdir -p lobjs
        for _s in src/l*.c; do
          case "$_s" in
            */lua.c|*/luac.c) continue;;
          esac
          $CC $CFLAGS -DLUA_COMPAT_5_3 -c "$_s" -o "lobjs/$(basename "$_s" .c).o"
        done
        $AR rcs liblua.a lobjs/*.o
        $RANLIB liblua.a
        mkdir -p $OUT/include $OUT/lib $OUT/lib/pkgconfig
        cp src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp $OUT/include/
        cp liblua.a $OUT/lib/
        cat > $OUT/lib/pkgconfig/lua.pc <<EOF
        prefix=$PREFIX
        exec_prefix=\${prefix}
        libdir=\${exec_prefix}/lib
        includedir=\${prefix}/include
        Name: Lua
        Description: Lua language engine
        Version: 5.4.8
        Libs: -L\${libdir} -llua -lm
        Cflags: -I\${includedir}
        EOF
    ]]
})
