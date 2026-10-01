require("lapack@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lapack/* .
        # BLOCKED, and recorded here so the failure is not rediscovered the
        # expensive way. LAPACK 3.12.1 is CMake-only: it ships no configure,
        # no configure.ac, no aclocal.m4 and no config.h.in, and SRC/ is 2038
        # Fortran .f files. The reference build reaches
        # CMakeLists.txt:313 enable_language(Fortran) inside
        # if(NOT LATESTLAPACK_FOUND) (the "user supplied no working LAPACK"
        # branch, :309) with no guard around it, and then
        # CheckTimeFunction compiles the Fortran second_*.f timing sources
        # (:320-330). Turning off the Fortran side is not an option either:
        # BUILD_SINGLE/BUILD_DOUBLE/BUILD_COMPLEX/COMPLEX16 all OFF is a
        # FATAL_ERROR at :215-219.
        #
        # No system in packages/ exports $FC or $F77, the NDK ships no Fortran
        # compiler at all, and there is no gfortran or flang on this build
        # host. See stage1.md.
        #
        # The switches below are what the recipe would use if a Fortran
        # compiler existed. Do not attempt this build until a system provides
        # one.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCBLAS=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})