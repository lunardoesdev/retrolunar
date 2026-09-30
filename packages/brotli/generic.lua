require("brotli@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/brotli/* .
        # Static libraries, headers and pkg-config files. Upstream 1.1.0 has
        # no option to leave out the brotli tool, so they are built
        # too; their zopfli path calls log2(), which links because the
        # system's LDFLAGS already carry -lm for Bionic.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
