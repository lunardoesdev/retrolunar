require("xxhash@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xxhash/* .
        # Upstream's CMake build lives in cmake_unofficial/, not at the top
        # level, so point -S at it. Static library, header, pkg-config file
        # and the xxhsum tool; nothing here ever runs a target binary.
        cmake -S cmake_unofficial -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
