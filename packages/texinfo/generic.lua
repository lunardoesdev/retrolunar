require("texinfo@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/texinfo/* .
        # Texinfo cross-builds native helpers; use host tools before the NDK in nested configures.
        PATH="/usr/bin:/bin:$PATH" BUILD_CC=/usr/bin/cc BUILD_AR=/usr/bin/ar BUILD_RANLIB=/usr/bin/ranlib ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # Keep nested config.status newer to prevent make from reconfiguring native helpers.
        find . -name config.status | xargs touch
        make
        make install
    ]]
})
