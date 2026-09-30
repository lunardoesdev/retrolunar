require("libuv@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libuv/* .
        # Static library, headers, pkg-config file and libuv's own tool
        # programs. The tools (uv_run, luvc, luv_echo) stay on: they are
        # small and are the only way to exercise a libuv build from the
        # target side. The docs need curl, so they are off.
        cmake -S . -B build $CMAKE_FLAGS -DLIBUV_BUILD_SHARED=OFF -DLIBUV_BUILD_TESTS=OFF -DLIBUV_BUILD_BENCH=OFF -DLIBUV_ENABLE_DOCS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
