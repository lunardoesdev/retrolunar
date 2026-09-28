require("gperf@clang-native")
require("bison@source")

return {
    build = [[
        cp -r $NESTDIR/source/bison/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Bison generates build-time tables with a native gperf executable.
        PATH="$NESTDIR/clang-native/bin:$PATH" make -j1
        make install
    ]]
}
