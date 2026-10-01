require("libgit2@source")
require("zlib")
require("openssl")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libgit2/* .
        # libgit2 1.9.7 is CMake-only: there is no configure.ac and no
        # generated configure, so there is no autotools timestamp guard and no
        # config template to touch. src/libgit2/config.h is an ordinary source
        # file, not a configure_file product.
        #
        # Static libgit2.a, the git2/ headers, libgit2.pc and the CMake
        # package config. BUILD_TESTS=OFF drops the Clar suite,
        # BUILD_CLI=OFF the git2 command-line program, BUILD_EXAMPLES=OFF the
        # example apps and BUILD_FUZZERS=OFF the fuzzers - all of which would
        # otherwise be compiled as target binaries nothing here runs.
        #
        # USE_HTTPS=OpenSSL uses the OpenSSL in this prefix for HTTPS, hashing
        # (USE_SHA1/USE_SHA256 default to the HTTPS provider, i.e. OpenSSL) and
        # TLS. USE_SSH=OFF leaves the SSH transport out: it needs libssh2,
        # which is a separate package, and the alternative "exec" provider
        # shells out to a git binary.
        #
        # USE_BUNDLED_ZLIB=OFF makes cmake/SelectZlib.cmake:10-25 run
        # find_package(ZLIB) and link the zlib in $PREFIX (it also adds
        # "zlib" to the .pc Requires, SelectZlib.cmake:18). Left at its
        # default the bundled deps/zlib would be compiled instead, duplicating
        # a package this prefix already has.
        #
        # REGEX_BACKEND=pcre2 selects the PCRE2 that is in this prefix.
        #
        # USE_ICONV=OFF is required on Android below API 28. src/util/fs_path.c
        # includes <iconv.h> under GIT_USE_ICONV (fs_path.c:1017) for macOS
        # path precomposition, and cmake sets GIT_USE_ICONV whenever
        # find_package(IntlIconv) succeeds (src/CMakeLists.txt:187-196).
        # Bionic exposes <iconv.h> from API 28 only, so this is what keeps the
        # 21/24 families compiling. Off everywhere keeps one artifact.
        #
        # USE_NSEC=OFF: st_mtim nanosecond fields are not uniformly available
        # across Bionic API levels and the feature is optional here.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DBUILD_EXAMPLES=OFF -DBUILD_FUZZERS=OFF -DUSE_SSH=OFF -DUSE_HTTPS=OpenSSL -DUSE_BUNDLED_ZLIB=OFF -DREGEX_BACKEND=pcre2 -DUSE_ICONV=OFF -DUSE_NSEC=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})