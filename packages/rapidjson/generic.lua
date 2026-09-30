require("rapidjson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/rapidjson/* .
        # rapidjson is header-only, so the build step below is empty by
        # design; the install is the whole package.
        #
        # RAPIDJSON_BUILD_EXAMPLES=OFF is load-bearing, not cosmetic.
        # example/CMakeLists.txt builds fifteen target executables
        # unconditionally, and it sets -Werror (plus -Weverything under
        # Clang) on them; the top-level file also appends -march=native,
        # which every NDK wrapper except x86_64/i686 rejects outright. No
        # upstream switch other than this one can stop it, and AGENTS.md
        # forbids a patch, so the option stays off.
        #
        # RAPIDJSON_BUILD_DOC=OFF stops doc/'s doxygen requirement.
        # RAPIDJSON_BUILD_TESTS=OFF skips test/, which needs the
        # thirdparty/gtest submodule the tag archive does not carry.
        cmake -S . -B build $CMAKE_FLAGS -DRAPIDJSON_BUILD_DOC=OFF -DRAPIDJSON_BUILD_EXAMPLES=OFF -DRAPIDJSON_BUILD_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})