require("openssl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/openssl/* .
        export ANDROID_NDK_ROOT="$NDK"
        # Upstream's android-* target config probes for the NDK tools by
        # name in PATH (it tests `which clang`, then `which <triple>-gcc`) and
        # dies without a flag to change that; current NDKs ship neither a
        # bare clang in bin/ nor a triple-gcc wrapper. So this one build puts
        # $TOOLBIN in front of PATH. It is a recipe-local exception: systems
        # do not do this, and no other recipe may rely on it.
        PATH="$TOOLBIN:$PATH"; export PATH
        # The target name and the API level come from the system, so this
        # recipe builds for any Android target rather than one hardcoded
        # android-arm64 at level 24.
        case "$HOST_ARCH" in
            aarch64) ssl_target=android-arm64 ;;
            armv7a) ssl_target=android-arm ;;
            i686) ssl_target=android-x86 ;;
            x86_64) ssl_target=android-x86_64 ;;
        esac
        ./Configure "$ssl_target" -D__ANDROID_API__="$ANDROID_API" --prefix="$OUT" --libdir=lib no-shared no-tests no-docs no-engine no-dso no-dynamic-engine
        make -j1
        make install_sw
    ]]
})
