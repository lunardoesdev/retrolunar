require("mbedtls@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/mbedtls/* .
        # Mbed TLS builds three libraries in one pass: the TLS library, the
        # X.509 and crypto libraries it is split across, and the DTLS
        # variant. All three are wanted; the programs and tests are host-side
        # and stay off.
        cmake -S . -B build $CMAKE_FLAGS -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF -DUSE_SHARED_MBEDTLS_LIBRARY=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
