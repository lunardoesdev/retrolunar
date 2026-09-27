require("zlib")
require("openssl")
require("expat")
require("sqlite")
require("aria2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/aria2/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --with-openssl --with-libzlib --with-libexpat --with-sqlite3 --without-libcares --without-libssh2 --disable-nls --disable-bittorrent --disable-metalink --disable-websocket
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4) -C src
        make -C src install
    ]]
})
