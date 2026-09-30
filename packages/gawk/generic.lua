require("gawk@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/gawk/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # Two templates, not one: the top-level configure.ac:472 and
        # extension/configure.ac:129 each declare AC_CONFIG_HEADERS([config.h:
        # configh.in]), and the top level has AC_CONFIG_SUBDIRS(extension) at
        # :494. extension/ ships its own configh.in, configure, aclocal.m4 and
        # Makefile.in, so it needs the same treatment as the top level.
        touch aclocal.m4 configure configh.in
        find . -name 'configh.in' | xargs touch
        find . -name 'configure' | xargs touch
        find . -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
