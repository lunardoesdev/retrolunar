-- distcc is a HOST tool, not a target library. `distcc` is a compiler
-- wrapper: it execs the compiler you point it at, so it is only meaningful
-- on the machine that is doing the compiling. `distccd` is the other half --
-- a network compile-server daemon that listens for preprocessed jobs and
-- runs the compiler remotely. Nothing in a target prefix can either exec a
-- host compiler or serve TCP compile jobs, so a target distcc has no
-- consumer. Consumers should require("distcc@native"), which resolves to
-- this file (the loader falls back to generic.lua for @native), exactly as
-- packages/bison/generic.lua does for gperf@native and
-- packages/libnl-3/generic.lua does for flex@native.
require("distcc@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/distcc/* .
        # configure.ac:11 says "As of 0.6cvs, distcc no longer uses automake,
        # only autoconf", so the tarball ships a hand-written Makefile.in and
        # no Makefile.am. There is exactly one config template, named by
        # AC_CONFIG_HEADERS(src/config.h) at configure.ac:15, so it is
        # src/config.h.in -- not a top-level config.h.in.
        #
        # --with-included-popt: configure.ac:320-328 auto-detects a system
        # libpopt and silently falls back to the bundled copy when the link
        # probe fails. Our prefix has no popt, so the fallback is what we
        # would get anyway; passing it says so outright and removes a
        # configure-time link probe whose answer depends on the search path.
        # popt/ is vendored source built by the top Makefile (Makefile.in:394),
        # not a sub-configure, so it needs no guard of its own.
        #
        # --disable-pump-mode: pump mode is the include server
        # (configure.ac:83-85), which defaults ON and pulls in
        # AM_PATH_PYTHON([3.1],,[:]) -- a host python3 dependency this
        # package has no use for. man/pump.1 ships in the tarball and is
        # listed in man1_MEN unconditionally (Makefile.in:386), so turning
        # pump mode off costs no man page.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-included-popt --disable-pump-mode
        touch aclocal.m4 configure src/config.h.in
        find . -name 'Makefile.in' | xargs touch
        # distcc builds no host programs and runs none: check_PROGRAMS and
        # check_include_server_PY (Makefile.in:427, :441) are built only by
        # `make check`, which this recipe never runs.
        make -j1
        make -j1 install
    ]]
})
