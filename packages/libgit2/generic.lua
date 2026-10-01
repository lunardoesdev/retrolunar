require("libgit2@source")
require("zlib")
require("openssl")
require("pcre2")

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
        # REGEX_BACKEND=pcre2 selects the PCRE2 in this prefix, and the
        # require("pcre2") above is what makes that selection reliable.
        # cmake/SelectRegex.cmake:24-29 does find_package(PCRE2) and then
        # MESSAGE(FATAL_ERROR "PCRE2 support was requested but not found")
        # if it is missing - a hard configure failure, not a silent fallback -
        # and cmake/FindPCRE2.cmake:19,22 looks for pcre2.h and a library
        # named pcre2-8, which is exactly what packages/pcre2 installs
        # (--enable-pcre2-8). The loader only orders a package after the
        # packages that require() it, so without that require whether PCRE2 is
        # in $PREFIX when libgit2 configures would depend on whatever else
        # happened to build first: a clean nest would fail at configure time
        # and a dirty one would work by accident.
        #
        # USE_ICONV=OFF is mandatory on every Android level below 28, and the
        # reason is not that the header is missing - it is not. Bionic ships
        # <iconv.h> at EVERY API level (21, 24, 26, 28 and 35 all find it,
        # e.g. ICONV_INCLUDE_DIR=/usr/include at API 21); what is gated is the
        # declarations, which carry __INTRODUCED_IN(28) in the NDK header. So a
        # program that CALLS iconv_open fails to compile below 28 ("call to
        # undeclared function 'iconv_open'") while a program that merely
        # includes the header does not.
        #
        # That is exactly what src/util/fs_path.c:1017 guards with
        # #ifdef GIT_USE_ICONV, and src/CMakeLists.txt:187-196 sets
        # GIT_USE_ICONV whenever find_package(IntlIconv) succeeds. The trap is
        # that our systems export -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        # (so cmake's compiler check does not need to run a target binary),
        # and cmake/FindIntlIconv.cmake:15 gates on check_function_exists
        # (iconv_open) - a LINK test. A static library does not resolve
        # symbols, so that probe SUCCEEDS even where iconv_open is unusable.
        # Reproduced with libgit2's own probe at API 21:
        #   STATIC_LIBRARY: "Looking for iconv_open - found", ICONV_FOUND TRUE
        #   default exe:     "Looking for iconv_open - not found"
        # So without this flag libgit2 would believe iconv works, set
        # GIT_USE_ICONV, and then fail to compile fs_path.c at API 21 and 24 -
        # a false positive created by our own try_compile setting, not by
        # Bionic. Off everywhere also keeps one artifact across all families.
        # It is upstream's own switch (CMakeLists.txt:77).
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DBUILD_EXAMPLES=OFF -DBUILD_FUZZERS=OFF -DUSE_SSH=OFF -DUSE_HTTPS=OpenSSL -DUSE_BUNDLED_ZLIB=OFF -DREGEX_BACKEND=pcre2 -DUSE_ICONV=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})