require("cjson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cjson/* .
        # Static library, headers and libcjson.pc. ENABLE_CUSTOM_COMPILER_FLAGS
        # is upstream's ON default and appends -Werror, plus -std=c89
        # -pedantic and a wide warning set, to CMAKE_C_FLAGS, so any warning
        # a current compiler adds becomes a hard build error. Off, because the
        # prefix should not inherit a 2017 warning policy.
        # ENABLE_CJSON_TEST=OFF drops the host test program. Nothing else is
        # installed: ENABLE_CJSON_UTILS defaults OFF and is a library.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DENABLE_CUSTOM_COMPILER_FLAGS=OFF -DENABLE_CJSON_TEST=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
