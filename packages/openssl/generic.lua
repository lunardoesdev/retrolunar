require("openssl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openssl/* .
        export ANDROID_NDK_ROOT="$NDK"
        ./Configure android-arm64 --prefix="$OUT" --libdir=lib no-shared no-tests no-docs
        make -j$(nproc 2>/dev/null || echo 4)
        make install_sw
    ]]
})
