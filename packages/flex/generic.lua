require("m4")
require("flex@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flex/* .
        # The bootstrap needs a runnable flex; the release ships the
        # generated parser, so skip it.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-static --disable-bootstrap
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
