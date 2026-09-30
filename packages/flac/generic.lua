require("libogg")
require("flac@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/flac/* .
        # Static libraries against the libogg in this prefix: libFLAC (the
        # format) and libFLAC++ (the C++ decoder interface). flac and metaflac
        # are bin_PROGRAMS; there is no switch that drops them without
        # --disable-programs, so they are built, installed and never run here.
        # --disable-version-from-git keeps configure from shelling out to git,
        # which AGENTS.md keeps out of the build path; the tarball's version
        # string is already substituted.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-version-from-git
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
