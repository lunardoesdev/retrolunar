require("abseil-cpp")
require("zlib")
require("protobuf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/protobuf/* .
        # Static libprotobuf, libprotobuf-lite, the headers, protobuf.pc and
        # the CMake package config, against the abseil already in this prefix.
        # abseil is found by cmake/abseil-cpp.cmake:16 via find_package(absl
        # CONFIG), which resolves against $CMAKE_PREFIX_PATH=$PREFIX from
        # $CMAKE_FLAGS. If it did not, :20 would fall through to a FetchContent
        # of abseil from GitHub at configure time, which is a network fetch in
        # the middle of a cross build; the require above is what prevents it.
        #
        # protobuf_BUILD_SHARED_LIBS=OFF: the default already follows
        # BUILD_SHARED_LIBS, which we do not set, but stating it keeps the
        # static shape independent of any other -D on the command line.
        # CMakeLists.txt:55 forces BUILD_SHARED_LIBS=ON when protobuf is
        # shared, to avoid ODR violations against a shared abseil.
        #
        # The protoc compiler is OFF. protobuf_BUILD_PROTOC_BINARIES=OFF (also
        # what stops the option cascade below) keeps three host-shaped things
        # out: the protoc binary itself, the protoc-gen-upb generator plugins
        # (cmake/install.cmake:66-70 installs one per generator), and libprotoc.
        # protoc is a code generator, not a runtime library, so a target prefix
        # has no use for it, and a target protoc could never be run here.
        #
        # That one switch is also what makes protobuf_BUILD_LIBUPB=OFF real
        # rather than inert. CMakeLists.txt:124 turns LIBPROTOC back ON if
        # protoc binaries or tests are wanted, and :132 then forces LIBUPB back
        # ON because "Building protoc binaries requires building libupb". With
        # protoc binaries off and tests off, LIBPROTOC stays off and LIBUPB=OFF
        # is honoured: libupb is only a private static dependency of protoc
        # (cmake/libupb.cmake:19 builds it as an internal add_library, not an
        # installed target), so dropping it takes ~60 source files and a large
        # generated table out of the build for nothing this prefix can use.
        #
        # protobuf_BUILD_TESTS=OFF and protobuf_BUILD_CONFORMANCE=OFF keep the
        # host test and conformance programs out. protobuf_BUILD_EXAMPLES=OFF is
        # the upstream default. protobuf_WITH_ZLIB=OFF keeps libz out of the
        # runtime; CMakeLists.txt:199 would otherwise find_package(ZLIB) and
        # define HAVE_ZLIB, and zlib is not a protobuf runtime dependency.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF \
            -Dprotobuf_BUILD_SHARED_LIBS=OFF \
            -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
            -Dprotobuf_BUILD_LIBUPB=OFF \
            -Dprotobuf_BUILD_TESTS=OFF \
            -Dprotobuf_BUILD_CONFORMANCE=OFF \
            -Dprotobuf_BUILD_EXAMPLES=OFF \
            -Dprotobuf_WITH_ZLIB=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})