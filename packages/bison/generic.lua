require("gperf@clang-native")
require("bison@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bison/* .
        # Bionic provides ffsl inline; keep the cache result for config.status rechecks.
        export ac_cv_func_ffsl=yes
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Bison generates build-time tables with a native gperf executable.
        PATH="$NESTDIR/clang-native/bin:$PATH" make -j1
        make install
    ]]
})
