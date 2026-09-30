require("googletest@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/googletest/* .
        # Static gtest, gtest_main, gmock and gmock_main with their headers,
        # CMake package configs and pkg-config files. Do not pass
        # -DINSTALL_GTEST=OFF: googletest's own install() rules live inside
        # that option's guard, so turning it off installs nothing at all (and
        # the duplicate legacy lib/ layout it controls is harmless).
        # googletest's and gmock's own tests are host programs and stay off.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -Dgtest_build_tests=OFF -Dgmock_build_tests=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
