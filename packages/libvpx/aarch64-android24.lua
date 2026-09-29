require("libvpx@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # The Android target tuple is a target fact, so it lives here rather
        # than in the generic recipe. libvpx's hand-written configure accepts
        # --target only - it has no --host/--build and rejects them as unknown
        # options - so the tuple alone selects the cross build.
        #
        # --sysroot goes in --extra-cflags on purpose: passing it as -isystem
        # breaks the libc++ include order for this toolchain.
        ./configure --prefix="$OUT" \
          --target=arm64-android-gcc \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared \
          --extra-cflags="--sysroot=$SYSROOT" \
          --extra-cxxflags="--sysroot=$SYSROOT"
        make -j1
        make install
    ]]
})
