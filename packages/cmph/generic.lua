-- cmph is a plain C library plus its `cmph` command-line generator, so it
-- is an ordinary TARGET package: nothing here invokes a compiler or runs a
-- target binary at build time.
--
-- The one build-time generator question, answered from the tree rather than
-- assumed: there is NO perl and NO python in this build. src/Makefile.am:2
-- declares `noinst_PROGRAMS = bm_numbers` and :36 builds it, but nothing in
-- the Makefiles invokes it, and the bdz lookup table that looks like a
-- generated header is a literal C array already in the tree
-- (src/bdz.c:20, `const cmph_uint8 bdz_lookup_table[] =`), not something
-- regenerated at build time. gendocs and scpscript are t2t/doc helpers for
-- the manual, not part of `make`.
--
-- The native autotools are build-time TOOLS: autoreconf -fi below executes
-- them, so they must be host binaries, which is what @native gives. Each
-- names a different package, so none of them resolves back to this file.
require("autoconf@native")
require("automake@native")
require("libtool@native")
require("m4@native")
require("cmph@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cmph/* .
        # The 2.0.2 tarball ships configure.ac but NO generated configure,
        # NO aclocal.m4 and NO Makefile.in anywhere in it (checked against
        # the tarball index, not only the extracted tree: zero Makefile.in
        # entries). ./configure therefore does not exist until autoreconf
        # runs, which needs the native autotools - those must RUN on the
        # build host, hence @native, and none is a target program.
        #
        # autoreconf is not in the recipe-hygiene list, but it is upstream's
        # own bootstrap for a tree in this shape and there is no alternative:
        # the alternative is not building at all.
        autoreconf -fi
        #
        # --disable-cxxmph: configure.ac:38-53 errors out with "cxxmph
        # demands a working c++0x compiler" when AC_COMPILE_STDCXX_0X fails.
        # The C++ binding is optional and nothing here needs it.
        # --disable-benchmarks: configure.ac:56-62 needs the host-only
        # hopscotch_map.h when enabled.
        # --disable-check is the upstream default (configure.ac:67-69: the
        # check-based unit tests are off unless asked for); passed so the
        # recipe does not lean on a default.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-cxxmph \
            --disable-benchmarks \
            --disable-check
        # configure.ac:5 is AC_CONFIG_HEADERS([config.h]) and config.h.in is
        # the only template in the tree. It is a GENERATED file after
        # autoreconf -fi, which is what makes this guard load-bearing rather
        # than merely tidy.
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})