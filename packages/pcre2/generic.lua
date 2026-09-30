require("pcre2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/pcre2/* .
        # The 8, 16 and 32 bit libraries, statically. C++ is off: pcre2grep
        # is the only C++ part, and this prefix is for libraries, not for a
        # grep replacement. The grep/pcre2grep programs are still built.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 --disable-cpp
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
