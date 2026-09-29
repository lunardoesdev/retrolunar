require("libvpx@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # libvpx's configure is hand-written (FFmpeg-style), not autoconf, so
        # neither $AUTOCONF_CONFIGURE_FLAGS nor the Autotools timestamp guard
        # applies here. Only the build-mode options live in this generic recipe;
        # the target triple, host/build and sysroot belong to the per-system
        # file, because they differ per system and $SYSROOT is not even
        # exported on systems such as clang-native.
        ./configure --prefix="$OUT" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared
        make -j1
        make install
    ]]
})
