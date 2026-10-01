require("json-c@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/json-c/* .
        # Static archive, headers and json-c.pc. The five switches are
        # each load-bearing and all are json-c defaults that are wrong for
        # a target prefix:
        #   BUILD_SHARED_LIBS=OFF  upstream defaults shared ON
        #   BUILD_APPS=OFF         builds json_parse, a host program
        #   BUILD_TESTING=OFF      the tests/ tree, host programs
        #   DISABLE_WERROR=ON      CMakeLists.txt:361-362 appends -Werror to
        #                          CMAKE_C_FLAGS when this is OFF, so any
        #                          warning a current NDK or host clang adds to
        #                          json_object.c becomes a hard build error.
        #                          The prefix should not inherit that.
        # json-c 0.19 renamed the old ENABLE_CUSTOM_COMPILER_FLAGS to
        # DISABLE_WERROR, so the flag is spelled as above and not as the
        # name 0.18 used.
        cmake -S . -B build $CMAKE_FLAGS \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DBUILD_APPS=OFF \
            -DBUILD_TESTING=OFF \
            -DDISABLE_WERROR=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
