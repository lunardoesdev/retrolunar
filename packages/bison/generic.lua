require("gperf@native")
require("bison@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bison/* .
        # Bison bakes its --prefix-derived data directory into the binary as
        # PKGDATADIR (Makefile.in: `echo '#define PKGDATADIR "$(pkgdatadir)"'`
        # -> lib/configmake.h -> src/files.c pkgdatadir()). The loader installs
        # into $OUT and then publishes with `cp -rf "$OUT"/. "$PREFIX"/` before
        # `rm -rf "$OUT"`, so the published binary points at a directory that no
        # longer exists and every skeleton/m4sugar lookup fails. A copy cannot
        # rewrite a compiled-in path, so the binary has to resolve it itself.
        # --enable-relocatable sets ENABLE_RELOCATABLE (m4/relocatable-lib.m4),
        # which turns set_program_name() into the progname.h:47 macro calling
        # set_program_name_and_installdir(), deriving the live prefix from
        # argv[0] and passing it to relocate2() at src/files.c:556.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-relocatable
        touch aclocal.m4 configure lib/config.in.h
        find . -name 'Makefile.in' | xargs touch
        # Bison generates build-time tables with a native gperf executable.
        make -j1
        make install
    ]]
})
