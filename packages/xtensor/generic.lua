require("xtensor@source")
-- BLOCKER: xtl is a hard, REQUIRED dependency and has no recipe in this tree.
-- xtensor/CMakeLists.txt:43 sets xtl_REQUIRED_VERSION 0.8.0 and line 53 runs
-- find_package(xtl 0.8.0 REQUIRED); there is no fallback that vendors or
-- downloads xtl. packages/xtl does not exist and topackage.md has no xtl
-- entry, so this require() cannot resolve today. See stage1.md.
require("xtl")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xtensor/* .
        # Header-only: add_library(xtensor INTERFACE) at CMakeLists.txt:202, so
        # nothing is compiled and the install is a file copy identical on every
        # system.
        #
        # xtensor's own target asks consumers for C++20 via
        # target_compile_features(xtensor INTERFACE cxx_std_20) at line 209.
        # That is an INTERFACE property, so it does not change how this build
        # compiles (nothing is compiled), but it does set the standard on every
        # consumer, and the headers do use the C++20 `concept` keyword
        # unguarded (include/xtensor/utils/xutils.hpp:590, :613).
        #
        # BUILD_TESTS and BUILD_BENCHMARK already default OFF (lines 216-217).
        # DOWNLOAD_GBENCHMARK (line 218) is only consulted by
        # add_subdirectory(benchmark) at line 250, which BUILD_BENCHMARK=OFF
        # never reaches, so no gbenchmark is fetched. XTENSOR_USE_XSIMD,
        # XTENSOR_USE_TBB and XTENSOR_USE_OPENMP default OFF (lines 62-64), so
        # the xsimd/TBB/OpenMP find_package calls at lines 83, 90 and 95 do not
        # run.
        #
        # find_package(nlohmann_json 3.1.1 QUIET) at line 57 is QUIET and
        # optional; it only enables xjson.hpp, which is not in the
        # single-include list (lines 331-335).
        cmake -S . -B build $CMAKE_FLAGS
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
