require("man-db@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/man-db/* .
        # The viewer, valgrind and grap helpers are not part of this prefix, so
        # their --with-* hooks are left empty the way LFS does. The system
        # unit dirs are left unset for the same reason.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-setuid \
            --enable-cache-owner=bin \
            --with-browser= \
            --with-vgrind= \
            --with-grap= \
            --with-systemdtmpfilesdir= \
            --with-systemdsystemunitdir=
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
