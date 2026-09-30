-- configure hard-requires gperf (configure.ac: "please install gperf"),
-- and src/Makefile.am also regenerates src/syscalls.perf{,.c} through
-- ${GPERF}. Both are build-time host executables, so gperf must come from
-- the native prefix; the loader puts $NATIVE_PREFIX/bin on PATH for every
-- block, cross blocks included.
require("gperf@native")
require("libseccomp@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libseccomp/* .
        # Static with PIC. The python bindings need cython and only the
        # --enable-python path asks for them, so they stay off by default.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared
        touch aclocal.m4 configure configure.h.in
        find . -name 'Makefile.in' | xargs touch
        # tools/ has one bin_PROGRAM (scmp_sys_resolver) and four noinst
        # programs; they are target binaries nothing in this prefix runs, so
        # build the library and install only what a consumer needs. The
        # narrow targets below keep both headers, the .pc and all 36 man
        # pages; `make -C src install` alone would drop the last two.
        # install-libLTLIBRARIES builds AND installs the library: a plain
        # `make -C src` only archives it into .libs/ and copies nothing into
        # $OUT, which would leave libseccomp.a missing from the prefix while
        # its headers, man pages and .pc all shipped.
        make -j1 -C src install-libLTLIBRARIES
        make -j1 -C include install-includeHEADERS
        make -j1 -C doc install-man
        make -j1 -C . install-pkgconfDATA
    ]]
})
