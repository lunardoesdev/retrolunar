require("simdjson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/simdjson/* .
        # Build only the library target. simdjson unconditionally adds its
        # tests, examples, benchmark and fuzz subdirectories on 64-bit hosts
        # and offers no option to turn them off, and those host programs link
        # -lrt, which Bionic does not provide. Naming the target is the way to
        # skip them; the install rules for the archive, the headers and the
        # generated single-header all hang off it.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
        cmake --build build --target simdjson --parallel 1
        cmake --install build
    ]]
})
