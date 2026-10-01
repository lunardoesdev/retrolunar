require("SpeexDSP@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/SpeexDSP/* .
        # Static library, the speex/ headers and speexdsp.pc, with no real
        # dependencies at all - SpeexDSP is its own thing.
        #
        # --disable-examples: libspeexdsp/Makefile.am:33-34 builds five
        # host programs under `if BUILD_EXAMPLES` -
        # testdenoise, testecho, testjitter, testresample and testresample2 -
        # and configure.ac:175-180 makes BUILD_EXAMPLES TRUE by default
        # (`if test "$enableval" != no`). Without this flag they are built on
        # every system, including cross targets. They are noinst_PROGRAMS so
        # they are not installed, but they are still compiled and linked,
        # which is the part that cannot work here.
        #
        # (An earlier version of this recipe claimed regressions/ held the
        # test programs and was not in SUBDIRS. That was wrong on both counts:
        # Makefile.am:14 and :16 are byte-identical, and regressions/ is not
        # in the tarball at all.)
        #
        # Makefile.am:14 SUBDIRS = libspeexdsp include doc win32 symbian ti
        # adds no further host programs: win32/, symbian/ and ti/ are
        # alternate-platform build files with no programs of their own.
        #
        # The timestamp guard names config.h.in because configure.ac:338 is
        # AC_CONFIG_HEADERS([config.h]) - the real template, checked in the
        # unpacked tree rather than assumed.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-examples
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
