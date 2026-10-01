require("graphite2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/graphite2/* .
        # -DBUILD_SHARED_LIBS=OFF: upstream defaults it ON (CMakeLists.txt:12).
        # A target prefix has no loader path for a versioned shared object,
        # the same reason the meson recipes here pass -Ddefault_library=static.
        # It also selects the "call" VM and the static-export define.
        #
        # -DBUILD_TESTING=OFF: upstream defaults it ON (CMakeLists.txt:13).
        # The test tree is host-side - it wants a host Python3 interpreter at
        # configure time (CMakeLists.txt:70, find_package(Python3 ... REQUIRED))
        # and builds a large harness set. Turning it off is also what removes
        # this package's only FreeType reference: tests/examples/CMakeLists.txt
        # is the sole user of find_package(Freetype), and it is reached only
        # through tests/, so graphite2 needs no FreeType at all.
        #
        # GRAPHITE2_VM_TYPE is left at its "auto" default (CMakeLists.txt:23).
        # CMAKE_BUILD_TYPE defaults to Release here (CMakeLists.txt:8-10),
        # which resolves "auto" to "direct" (CMakeLists.txt:57-58); "direct"
        # requires GCC or Clang (CMakeLists.txt:63), which every system in
        # this tree has.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})