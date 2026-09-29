require("libandroid-spawn@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libandroid-spawn/* .
        cat > CMakeLists.txt <<'EOF'
        cmake_minimum_required(VERSION 3.10)
        project(libandroid_spawn LANGUAGES CXX)
        add_library(android_spawn STATIC posix_spawn.cpp)
        set_target_properties(android_spawn PROPERTIES OUTPUT_NAME android-spawn)
        install(TARGETS android_spawn ARCHIVE DESTINATION lib)
        install(FILES posix_spawn.h DESTINATION include RENAME spawn.h)
        install(FILES LICENSE DESTINATION share/licenses/libandroid-spawn)
        EOF
        cmake -S . -B build $CMAKE_FLAGS
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
