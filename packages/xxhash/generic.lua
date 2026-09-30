require("xxhash@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xxhash/* .
        # Upstream's CMake build lives in cmake_unofficial/, not at the top
        # level, so point -S at it. Static library, header, pkg-config file
        # and the xxhsum tool; nothing here ever runs a target binary.
        # CMAKE_POLICY_VERSION_MINIMUM because xxHash still asks for
        # "cmake_minimum_required(VERSION 3.1)", which cmake 4.x refuses
        # without a policy floor.
        cmake -S cmake_unofficial -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
