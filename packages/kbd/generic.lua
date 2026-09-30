require("kbd@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/kbd/* .
        # --disable-vlock because vlock needs PAM, as in LFS.
        #
        # LFS additionally strips resizecons with sed, but that is not needed
        # here: configure sets RESIZECONS_PROGS=yes only for i386/x86_64
        # (configure.ac:153-154) and the aarch64 target falls through to the
        # [*] case which sets it to no (configure.ac:155), so resizecons is
        # already excluded and the upstream source is left alone.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-vlock
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
