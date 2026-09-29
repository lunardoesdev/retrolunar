require("util-linux@source")
require("ncurses")

return recipe({
    build = [[
        cp -r $NESTDIR/source/util-linux/* .
        # --without-cap-ng drops the only libcap dependency (configure.ac:1690
        # makes setpriv require cap_ng); libcap itself is not in this prefix
        # and has no reachable upstream source.
        #
        # The python bindings, liblastlog2 and libuuid are off because those
        # libraries are not in the prefix, and asciidoc is off for the same
        # reason, which is what stops the man pages from being regenerated.
        #
        # more and vipw fall back to the editor path _PATH_VI, which glibc
        # declares in <paths.h> and Bionic does not. Both have upstream
        # build-* feature options (meson_options.txt 'build-more' and
        # 'build-vipw'), so they are turned off rather than patched.
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --without-cap-ng \
            --disable-asciidoc \
            --disable-pylibmount \
            --disable-liblastlog2 \
            --disable-libuuid \
            --disable-more \
            --disable-vipw \
            --disable-nls
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make
        make install
    ]]
})
