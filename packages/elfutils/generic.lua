require("bzip2")
require("xz")
require("zlib")
require("elfutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/elfutils/* .
        # Debuginfod is not reachable from a build machine; libelf is the part
        # of Elfutils that the rest of the system needs.
        #
        # Elfutils does not build on Android or on mingw, and the reason is
        # upstream of everything below. configure.ac:650-658 is an
        # unconditional top-level block - not inside any AS_IF, with no
        # AC_ARG_ENABLE guarding it:
        #
        #   651: AC_SEARCH_LIBS([argp_parse], [argp])
        #   654:   no) AC_MSG_FAILURE([failed to find argp_parse]) ;;
        #
        # argp_parse is a glibc extension. Bionic has none at any API level -
        # the NDK r28b sysroot ships no argp.h at all - so no new
        # aarch64-androidNN target changes it, unlike nl_langinfo (API 26) or
        # posix_spawn (API 28), which are real __INTRODUCED_IN gates that a
        # higher API level really does unblock. packages/elfutils/stage3.md
        # records the build: configure dies at that probe, AC_OUTPUT never
        # runs, and neither config.h nor Makefile is ever created - so the
        # -C libelf steps below do not execute on a target.
        #
        # elfutils 0.193 ships no switch that avoids the probe either. All 47
        # --enable/--disable/--with/--without options in ./configure --help
        # were enumerated and none drops libdw, libdwfl, libstack, libebl or
        # tests/ from the unconditional SUBDIRS line (Makefile.am:31-32).
        #
        # So what is the -C libelf scoping below for? NOT for rescuing this
        # package: no flag reaches configure.ac:651, and the blocker is
        # strictly upstream of it. It avoids compiling libdw, libdwfl,
        # libstack, libbacktrace, backends/ and the test suite only to discard
        # all of it, and it is the shape the build would take if configure ever
        # did succeed - libelf compiles standalone: libelf/Makefile.in:116
        # needs only $(top_builddir)/config.h, config/eu.am:34 supplies
        # -iquote . -I.. and -I$(top_srcdir)/lib for common.h and abstract.h,
        # and libelf's link line (libelf_so_LDLIBS, libelf/Makefile.in:642)
        # never references argp_LDADD. On clang-native - the one system whose
        # glibc has <argp.h>, so configure does get through - that saving is
        # real. clang-native is untested for this package: there is no stamp
        # and no artifact for it in ./nest.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 -C libelf
        make -j1 -C libelf install
        mkdir -p $OUT/lib/pkgconfig
        cp config/libelf.pc $OUT/lib/pkgconfig/
    ]]
})
