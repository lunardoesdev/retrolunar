require("libvpx@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # libvpx's configure is hand-written (FFmpeg-style), not autoconf, so
        # $AUTOCONF_CONFIGURE_FLAGS does not apply and no Autotools timestamp
        # guard is needed. Native targets need no tuple: libvpx detects the
        # host. Android targets are served by android.lua, which the Android
        # systems reach through their recipe_fallbacks.
        ./configure --prefix="$OUT" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared
        make -j1
        make install
    ]]
})
