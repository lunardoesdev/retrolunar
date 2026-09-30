require("zlib-ng")
require("zlib")
require("bzip2")
require("xz")
require("zstd")
require("openssl")
require("minizip-ng@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/minizip-ng/* .
        # Static library and pkg-config file, linked against the
        # compression libraries already in this prefix. MZ_FETCH_LIBS=OFF is
        # what stops the build from downloading its own copies: the option
        # list has no "prefer external" switch, it has fetch switches, so
        # switching those off is how an external zlib-ng is used. Encryption
        # and compression backends follow what this prefix has.
        # MZ_COMPAT would rename the library to libminizip, so it stays off.
        cmake -S . -B build $CMAKE_FLAGS -DZLIBNG_PREFER_EXTERNAL=ON -DBUILD_SHARED_LIBS=OFF -DMZ_FETCH_LIBS=OFF -DMZ_FORCE_FETCH_LIBS=OFF -DMZ_BUILD_TESTS=OFF -DMZ_BUILD_UNIT_TESTS=OFF -DMZ_BUILD_FUZZ_TESTS=OFF -DMZ_CODE_COVERAGE=OFF -DMZ_COMPAT=OFF -DMZ_OPENSSL=ON -DMZ_BZIP=ON -DMZ_LZMA=ON -DMZ_ZSTD=ON -DMZ_PKCRYPT=ON -DMZ_WZAES=ON -DMZ_ICONV=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
