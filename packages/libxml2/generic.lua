require("libxml2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libxml2/* .
        # --without-python and --without-docs are already this release's
        # upstream defaults (configure.ac:579 runs the Python probe only for
        # an explicit "yes", configure.ac:563 likewise for docs), but an
        # explicit "yes" pulls a hard doxygen/xsltproc requirement
        # (configure.ac:589-593). Both are stated so an upstream default
        # flip cannot quietly add a host toolchain to a cross build.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --without-python --without-docs
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})