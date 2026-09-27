require("libvpx@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        ./configure --target=arm64-android-gcc --prefix="$OUT" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared \
          --extra-cflags="--sysroot=$SYSROOT" \
          --extra-cxxflags="--sysroot=$SYSROOT"
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
