require("libnuma@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libnuma/* .
        # Static with PIC. numactl's numa_init() constructor is wired in with
        # -Wl,-init, which only applies to a shared object, so consumers of
        # the static library must call numa_available() themselves; that is
        # libnuma's documented entry point anyway.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        # One non-recursive Makefile whose bin_PROGRAMS (numactl, numastat,
        # numademo, migratepages, migspeed, memhog) are host tools. Build the
        # library on its own, then install only the library, the public
        # headers and numa.pc; the man pages belong to the tools.
        make -j1 libnuma.la
        make -j1 install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA
    ]]
})
