require("nanopb@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/nanopb/* .
        # CMake build of the static runtime library, the four public headers
        # and the CMake package config. The generator (a protoc plugin written
        # in Python, shipped with its own protoc shim that wants the
        # grpcio-tools package) runs on the build host, not on a target, so
        # nanopb_BUILD_GENERATOR is off. The runtime part is the only part a
        # target prefix can use.
        cmake -S . -B build $CMAKE_FLAGS -Dnanopb_BUILD_GENERATOR=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})