require("wolfssl@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/wolfssl/* .
        # CMake, not Autotools: the tag archive ships Makefile.am but no
        # generated configure, so ./configure is not available without
        # running upstream's autogen.sh with the native autotools.
        # Static library, with the OpenSSL 3.x API compatibility layer on.
        # Examples off (they are host programs); wolfSSL's CMake builds the
        # test suite only when asked for it.
        # WOLFSSL_CRYPT_TESTS is off because that test program is a host
        # binary that pulls in Android's logcat via WOLFSSL_ANDROID_DEBUG,
        # which needs the platform liblog rather than anything in this
        # prefix. Examples are off for the same reason: host programs.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DWOLFSSL_EXAMPLES=no -DWOLFSSL_CRYPT_TESTS=no -DWOLFSSL_OPENSSLEXTRA=yes
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
