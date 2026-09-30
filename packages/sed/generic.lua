require("sed@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/sed/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS
        # configure.ac is AC_CONFIG_HEADERS([config.h:config_h.in]) - the template
        # is config_h.in, underscore and not a dot, and there is no
        # config.h.in anywhere in the tree.
        touch aclocal.m4 configure config_h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
