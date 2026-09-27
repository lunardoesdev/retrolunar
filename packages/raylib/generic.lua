require("raylib@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/raylib/* .
        cmake -S . -B build $CMAKE_FLAGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_GAMES=OFF -DPLATFORM=Android -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=21 -DANDROID_NDK="$NDK" -DANDROID_STL=c++_static
        cmake --build build -j$(nproc 2>/dev/null || echo 4)
        cmake --install build
    ]]
})
