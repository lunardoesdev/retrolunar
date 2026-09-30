require("m4")
require("flex@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flex/* .
        # The bootstrap needs a runnable flex; the release ships the
        # generated parser, so skip it. Static with PIC, like the rest of
        # the prefix: flex's libfl is incidental to the tool, and a shared
        # libfl would need a loader path a target has no use for.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-bootstrap
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
