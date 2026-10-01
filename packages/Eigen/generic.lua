require("Eigen@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/Eigen/* .
        # Header-only library: the eigen target is an INTERFACE library, so
        # nothing is compiled and the install is a file copy that is
        # identical on every system. cmake runs only to drive the install
        # rules, which is what produces the generated Eigen/Version header
        # (CMakeLists.txt:238), eigen3.pc and the CMake package config.
        #
        # Everything below defaults to ON when Eigen is the top-level project,
        # which is exactly the case here, and all of it is host-side:
        # EIGEN_BUILD_TESTING (line 59, defaults to CTest's BUILD_TESTING) -
        # the test suite; EIGEN_BUILD_DOC (line 80) - doxygen; EIGEN_BUILD_DEMOS
        # (line 82) - example programs; EIGEN_BUILD_BLAS and EIGEN_BUILD_LAPACK
        # (lines 63-64) - the bundled LAPACK/BLAS helper libraries, which are
        # Fortran/C host builds with no place in a target prefix. The two
        # benchmark suites (lines 72-73) already default OFF.
        #
        # EIGEN_BUILD_PKGCONFIG and EIGEN_BUILD_CMAKE_PACKAGE stay ON (lines
        # 86, 88): both are how consumers find the headers, and Eigen has no
        # compiled artifact that could be wrong-arch.
        #
        # install(DIRECTORY Eigen DESTINATION include) at line 236 is what
        # copies the WHOLE header tree - Eigen/src, Eigen/unsupported and all -
        # which is why this recipe runs upstream's own install rather than
        # copying headers by hand.
        cmake -S . -B build $CMAKE_FLAGS -DEIGEN_BUILD_TESTING=OFF -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_DEMOS=OFF -DEIGEN_BUILD_BLAS=OFF -DEIGEN_BUILD_LAPACK=OFF -DEIGEN_BUILD_BTL=OFF -DEIGEN_BUILD_SPBENCH=OFF -DEIGEN_BUILD_PKGCONFIG=ON -DEIGEN_BUILD_CMAKE_PACKAGE=ON
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
