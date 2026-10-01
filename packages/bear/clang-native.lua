-- bear is a COMPILER ADAPTER: it LD_PRELOADs an interposer onto the host
-- compiler/linker driver, so it has to run on the machine doing the build.
-- A cross-built bear could never intercept anything here, and running a
-- target binary is forbidden outright (AGENTS.md, 'Known platform walls').
-- So this package is NATIVE-ONLY: there is no generic.lua, and
-- clang-native.lua is the whole build.
--
-- The dependency block is the honest part: gRPC is NOT in this prefix and
-- cannot be made to be. third_party/grpc/CMakeLists.txt:28-43 is an
-- ExternalProject_Add that GIT_CLONES grpc v1.49.2 from github at build
-- time, which AGENTS.md forbids outright ("No jj/git commands inside
-- recipes; no network access at build time"). Every alternative it tries
-- first (pkg_check_modules protobuf>=3.11 grpc++>=1.26 plus find_program
-- protoc and grpc_cpp_plugin, :1-23) also fails, because the repo carries
-- protobuf but no grpc. There is no flag that turns the clone off.
--
-- That makes this a recorded blocker, not a recipe to force through: see
-- stage1.md, every row is WILL NOT BUILD.
require("bear@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bear/* .
        # cmake_minimum_required is 3.12 (CMakeLists.txt:1).
        # ENABLE_UNIT_TESTS and ENABLE_FUNC_TESTS both default ON (:15-16)
        # and the superbuild runs them with TEST_BEFORE_INSTALL 1 (:88-92),
        # which executes target binaries. Both are host-program concerns and
        # are off. The grpc clone remains and is the blocker.
        cmake -S . -B build $CMAKE_FLAGS \
            -DENABLE_UNIT_TESTS=OFF \
            -DENABLE_FUNC_TESTS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})