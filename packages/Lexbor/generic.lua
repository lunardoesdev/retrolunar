require("Lexbor@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/Lexbor/* .
        # Static liblexbor_static, the lexbor/ headers, lexbor.pc and a CMake
        # package config under lib/cmake/lexbor.
        #
        # LEXBOR_BUILD_SHARED=OFF: lexbor defaults shared ON (:52) and a shared
        # object would want a loader path a target has no use for. The static
        # target is liblexbor_static, named at :96, and it is the one the .pc
        # names too.
        #
        # Everything else is already OFF upstream and is left alone rather than
        # restated: LEXBOR_BUILD_TESTS (:54), LEXBOR_BUILD_TESTS_CPP (:55),
        # LEXBOR_BUILD_EXAMPLES (:53), LEXBOR_BUILD_UTILS (:58),
        # LEXBOR_BUILD_BENCHMARKS (:57), LEXBOR_BUILD_WASM (:51) and
        # LEXBOR_BUILD_FUZZER. Those are what the add_subdirectory calls at
        # :367-396 hang off, so they are the host-program gate.
        #
        # LEXBOR_WITHOUT_THREADS is ON by default (:51) and its own comment says
        # "Not used now, for the future" (:8). No pthread is referenced
        # anywhere under source/lexbor, so there is no thread library to
        # resolve and no reason to pass it.
        cmake -S . -B build $CMAKE_FLAGS -DLEXBOR_BUILD_SHARED=OFF
        cmake --build build --parallel 1
        cmake --install build
        # lexbor.pc's Libs is a genuine upstream packaging defect, on every
        # system. lexbor.pc.in renders `Libs: -L${libdir} -l@PROJECT_NAME@`,
        # and CMakeLists.txt:193 sets PROJECT_NAME to "lexbor", so the
        # installed file says -llexbor. But with LEXBOR_BUILD_SHARED=OFF the
        # only archive built is the static one, liblexbor_static.a
        # (CMakeLists.txt:211-221, installed by config.cmake:345-353). Every
        # pkg-config consumer would be told to link a library that is not in
        # the prefix. The template has no @variable@ a cmake option could
        # redirect - the substitute is the project name and nothing else - so
        # no LEXBOR_* flag fixes it.
        #
        # This rewrites the .pc in $OUT, not an upstream source file. That is
        # inside what AGENTS.md:238-254 permits: the no-patch rule covers
        # lexbor.pc.in and the sources it is generated from, while a .pc that
        # cmake --install wrote into $OUT is our own build output, on the same
        # lines the loader already rewrites there for the same reason ($OUT to
        # $PREFIX, src/loader.lua:454-468). packages/glog/generic.lua:68-69 is
        # the worked example of exactly this shape. It is a plain
        # substitution of one generated field, not a patch.
        #
        # The whole Libs: line is replaced, not appended to, because pkg-config
        # resolves a repeated key last-key-wins, which would drop the -L
        # rather than add to it. The -L${libdir} is kept. The replacement text
        # contains no $OUT, so the loader's staged-.pc pass prints it verbatim,
        # and the rewrite cannot double-apply because cmake --install
        # regenerates the .pc from lexbor.pc.in on every build.
        awk '{ if ($0 ~ /^Libs:/) print "Libs: -L${libdir} -llexbor_static"; else print }' "$OUT/lib/pkgconfig/lexbor.pc" > "$WORK/lexbor.pc"
        cp "$WORK/lexbor.pc" "$OUT/lib/pkgconfig/lexbor.pc"
    ]]
})