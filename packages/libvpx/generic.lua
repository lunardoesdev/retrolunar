require("libvpx@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # libvpx's configure is hand-written (FFmpeg-style), not autoconf,
        # so the Autotools timestamp guard does not apply here.
        ./configure --target=arm64-android-gcc --prefix="$OUT" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared \
          --extra-cflags="--sysroot=$SYSROOT" \
          --extra-cxxflags="--sysroot=$SYSROOT"
        make -j1
        make install
    ]]
})
