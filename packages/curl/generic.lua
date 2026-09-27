require("zlib")
require("curl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/curl/* .
        # OpenSSL static archives reference stderr, which API 21 only
        # provides as a macro (real symbol needs 23+); curl's configure
        # probes fail to link. Stick to no-ssl until the floor moves.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-ssl --with-zlib="$PREFIX" --without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3 --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-docs
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4) -C lib
        make -C lib install
        make -C include install
        make install-pkgconfigDATA
    ]]
})
