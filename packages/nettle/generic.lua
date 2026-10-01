require("gmp")
require("nettle@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/nettle/* .
        # Static libnettle/libhogweed against the GMP in this prefix.
        #   --disable-mini-gmp  nettle bundles a small GMP shim and uses it
        #                       by default; the real GMP is already here, and
        #                       configure finds it through the prefix's
        #                       pkg-config path.
        #   --disable-documentation  drops the texinfo manual, which would
        #                       otherwise want makeinfo/sgml on the host.
        #   --enable-public-key  on by default; nettle's own code, no
        #                       external library, so it is left alone.
        # The config template is top-level config.h.in: configure.ac:11 is
        # AC_CONFIG_HEADER([config.h]) in the singular form, and the tarball
        # ships configure, Makefile.in and config.h.in already generated.
        # No --with-pic and no --enable-pic: nettle's configure.ac:60-62
        # declares AC_ARG_ENABLE(pic, AS_HELP_STRING([--disable-pic], ...),
        # [enable_pic=yes]) - PIC is ON by default and the only flag is the
        # negative one. An earlier version of this recipe passed
        # --with-pic, which is not a nettle option at all; configure accepts
        # it silently, prints "WARNING: unrecognized options" and carries
        # on, so the recipe looked deliberate and was not.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-shared \
            --enable-static \
            --disable-mini-gmp \
            --disable-documentation
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
