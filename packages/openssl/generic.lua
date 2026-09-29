require("openssl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openssl/* .
        export ANDROID_NDK_ROOT="$NDK"
        # OpenSSL defaults to the highest NDK API; build for this system's API 24.
        ./Configure android-arm64 -D__ANDROID_API__=24 --prefix="$OUT" --libdir=lib no-shared no-tests no-docs no-ui-console no-engine no-dso no-dynamic-engine
        make
        make install_sw
    ]]
})
