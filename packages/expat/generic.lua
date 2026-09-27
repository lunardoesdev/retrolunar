require("expat@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/expat/* .
        cmake -S . -B build $CMAKE_FLAGS -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
