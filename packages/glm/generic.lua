require("glm@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/glm/* .
        # Header-only library: the install target copies the glm/ header tree
        # into include/glm and writes the CMake package config. Nothing is
        # compiled, so the result is byte-for-byte the same on every system and
        # there is no architecture to check.
        # GLM_BUILD_LIBRARY=OFF drops upstream's convenience archive, which is
        # a single empty translation unit (glm/detail/glm.cpp) built only so
        # IDEs have something to show. GLM_BUILD_TESTS=OFF is upstream's
        # default, passed explicitly because the test programs are host code.
        cmake -S . -B build $CMAKE_FLAGS -DGLM_BUILD_LIBRARY=OFF -DGLM_BUILD_TESTS=OFF -DGLM_BUILD_INSTALL=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
