require("cjson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/cjson/* .
        # Static library and headers. The upstream test suite is a host
        # program, so it is off; the utils (cJSON_add/cJSON_pretty) are
        # ordinary target programs and stay on.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DENABLE_CJSON_TEST=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
