require("gperf@native")
require("bison@source")

-- Found for every Android target through the systems' recipe_fallbacks,
-- so there is no per-target copy of this recipe.
return recipe({
    build = [[
        cp -r $NESTDIR/source/bison/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Bison generates build-time tables with a native gperf executable.
        make -j1
        make install
    ]]
})
