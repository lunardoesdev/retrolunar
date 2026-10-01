require("lapack@source")

return recipe({
    build = [[
        # BLOCKED. This package has no buildable form on any system in this
        # tree, so the recipe refuses here rather than carrying a cmake
        # invocation that is certain to fail further in.
        #
        # LAPACK 3.12.1 is CMake-only: it ships no configure, no
        # configure.ac, no aclocal.m4 and no config.h.in, and SRC/ is 2038
        # Fortran .f files. The reference build reaches CMakeLists.txt:313
        # enable_language(Fortran) inside if(NOT LATESTLAPACK_FOUND) (the
        # "user supplied no working LAPACK" branch, :309) with no guard around
        # it -- unlike the neighbouring branch at :286, which wraps its own
        # enable_language(Fortran) in if(CMAKE_Fortran_COMPILER). Turning the
        # Fortran side off does not avoid it either: CMakeLists.txt:215-219
        # makes "all four precisions off" a FATAL_ERROR.
        #
        # No system in packages/ exports $FC or $F77, the NDK ships no Fortran
        # compiler, and this build host has no gfortran or flang. See
        # stage1.md for the full evidence and for what would unblock it.
        echo "lapack: BLOCKED - Reference-LAPACK 3.12.1 cannot be built here." >&2
        echo "lapack: CMakeLists.txt:313 calls enable_language(Fortran) unguarded" >&2
        echo "lapack: for the reference implementation, and no system in" >&2
        echo "lapack: packages/ exports \$FC or \$F77 (no NDK or host Fortran)." >&2
        echo "lapack: This is a known toolchain gap, not a build regression." >&2
        echo "lapack: See packages/lapack/stage1.md. Not building." >&2
        exit 1
    ]]
})