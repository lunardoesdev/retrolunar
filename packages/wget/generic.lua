require("zlib")
require("wget@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/wget/* .
        # Same openssl/API-21 stderr reason as curl: no ssl for now.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-ssl --without-libpsl --without-libidn --without-libidn2 --disable-pcre --disable-pcre2 --disable-nls
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4) -C src
        make -C src install
    ]]
})
