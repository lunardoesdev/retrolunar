require("nghttp2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/nghttp2/* .
        # The library alone: no applications, no examples, no tests, no
        # Python or Rust bindings. The TLS backend is off, since that would
        # need an SSL library and this prefix keeps the core protocol and
        # HPACK code dependency-free.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-app --disable-examples --disable-tests --disable-python-bindings --disable-rust-bindings --without-libxml2 --without-libevent-openssl --without-jansson --without-c-ares --without-libev --without-zlib
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
