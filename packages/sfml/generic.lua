require("freetype")
require("sfml@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/sfml/* .
        cmake -S . -B build $CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DSFML_BUILD_EXAMPLES=OFF -DSFML_BUILD_TEST_SUITE=OFF -DSFML_BUILD_DOC=OFF -DSFML_BUILD_WINDOW=ON -DSFML_BUILD_GRAPHICS=ON -DSFML_BUILD_AUDIO=ON -DSFML_BUILD_NETWORK=ON -DSFML_BUILD_SYSTEM=ON -DSFML_USE_STATIC_STD_LIBS=ON
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
