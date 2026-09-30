require("openssl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openssl/* .
        # No NDK plumbing here, and deliberately: $NDK, $TOOLBIN and
        # $ANDROID_API are unset on this system, and handing openssl an
        # android-* target without them does not fail - android_ndk() in
        # Configurations/15-android.conf returns early for any target name
        # beginning with "android", before it ever reads
        # $ENV{ANDROID_NDK_ROOT}, so the build would run against host headers
        # with no sysroot and no API level. The Android recipe is android.lua.
        #
        # HOST_OS, not HOST_ARCH: x86_64-mingw and clang-native are both
        # x86_64, so the arch cannot tell them apart, while HOST_OS is
        # mingw32 vs linux. The `*)` arm refuses rather than guessing.
        case "$HOST_OS" in
            linux) ssl_target=linux-x86_64 ;;
            mingw32) ssl_target=mingw64 ;;
            *) echo "openssl: unsupported HOST_OS $HOST_OS" >&2; exit 1 ;;
        esac
        ./Configure "$ssl_target" --prefix="$OUT" --libdir=lib no-shared no-tests no-docs no-engine no-dso no-dynamic-engine
        make -j1
        make install_sw
    ]]
})
