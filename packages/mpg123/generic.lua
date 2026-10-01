require("mpg123@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/mpg123/* .
        # The release tarball ships a genuine generated configure (GNU
        # Autoconf 2.71, 702414 bytes), aclocal.m4 (83526) and Makefile.in
        # (458218), so no autoreconf is needed and no host autotools are
        # required.
        #
        # The config template is src/config.h.in - it is the only one in the
        # tree, and there is no top-level template.
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
