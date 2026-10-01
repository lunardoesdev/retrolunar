require("SuiteSparse@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/SuiteSparse/* .
        # Static libraries, the include/suitesparse headers, one .pc per
        # package and one CMake config per package.
        #
        # BUILD_SHARED_LIBS=OFF / BUILD_STATIC_LIBS=ON: SuiteSparsePolicy
        # .cmake:178 defaults BUILD_SHARED_LIBS to ON and :187 to
        # BUILD_STATIC_LIBS ON, so only the first has to be turned off. A
        # target prefix here has no loader path for a versioned shared object;
        # every other autotools package in this tree passes
        # --enable-static --disable-shared, which is the same decision.
        #
        # The project list. SuiteSparse is 18 libraries with three different
        # dependency tiers, and its default is to build all of them
        # (CMakeLists.txt:36, SUITESPARSE_ENABLE_PROJECTS="all", expanded at
        # :40-44 to SUITESPARSE_ALL_PROJECTS at :26-27). Three of those cannot
        # be built here at all, and one of them pulls in the largest library
        # in the tree:
        #
        #   * umfpack, spqr and paru need a Fortran BLAS. CMakeLists.txt:261-267
        #     names exactly which projects make BLAS mandatory, and
        #     SuiteSparse_config/cmake_modules/SuiteSparseBLAS.cmake ends in an
        #     unconditional `find_package ( BLAS REQUIRED )` - there is no
        #     fallback, and no vendor list here supplies one.
        #
        #     There is no usable BLAS or LAPACK in this prefix today, and the
        #     two recipes that would provide them are not usable yet:
        #       - packages/openblas exists and its recipe (0.3.34,
        #         NOFORTRAN=1 NO_SHARED=1) would give a static libopenblas.a,
        #         but the directory holds only generic.lua and source.lua: no
        #         stage1.md, no stage2.md, no stage3.md. It has not been
        #         through review and has never been built.
        #       - packages/lapack exists, but its generic.lua is a blocked
        #         placeholder: LAPACK 3.12.1 is CMake-only with 2038 Fortran
        #         sources and its own recipe says "Do not attempt this build
        #         until a system provides one" (a Fortran compiler). No system
        #         in packages/ exports $FC or $F77 and the NDK has none.
        #     Nothing BLAS- or LAPACK-shaped is present in nest/ either.
        #     So this recipe must not require either of them, and cannot use
        #     CHOLMOD's supernodal module, which needs both.
        #     topackage.md:295-296 still lists OpenBLAS and LAPACK unchecked,
        #     but that file is a backlog, not an inventory: the two
        #     directories above appeared without it being ticked.
        #   * lagraph is the reason graphblas is here: CMakeLists.txt:105-111
        #     appends "graphblas" to the list whenever "lagraph" is in it.
        #     GraphBLAS is 6055 of the tarball's 14131 files, and upstream
        #     itself carries a dedicated option to keep it out of a static
        #     build, GRAPHBLAS_BUILD_STATIC_LIBS, whose help string at
        #     CMakeLists.txt:63-65 says "building the library takes a long
        #     time". With it excluded, nothing in the list below depends on it.
        #
        # So this is the BLAS-free remainder: the four orderings (AMD, CAMD,
        # COLAMD, CCOLAMD) plus CHOLMOD, and the standalone solvers
        # (CXSparse, KLU with BTF, LDL, Mongoose, RBio, SPEX) and the shared
        # configuration header package SuiteSparse_config that CMakeLists.txt
        # :218-240 requires for all of them.
        #
        # SUITESPARSE_REQUIRE_BLAS=OFF is the other half of dropping umfpack,
        # spqr and paru. SuiteSparse_config/CMakeLists.txt:118-127 only
        # reaches SuiteSparseBLAS (the REQUIRED lookup) when that option is
        # ON; with it OFF it includes SuiteSparseBLAS32.cmake directly, which
        # sets SuiteSparse_BLAS_integer to int32_t and never calls
        # find_package. That is what fills in the
        # `SUITESPARSE_BLAS_INT @SuiteSparse_BLAS_integer@` substitution at
        # SuiteSparse_config/Config/SuiteSparse_config.h.in:580, so the
        # generated SuiteSparse_config.h is complete either way. The guard at
        # CMakeLists.txt:265-267 makes this combination a fatal error if a
        # BLAS-requiring project is still in the list, so the two settings
        # have to agree - which is why the list above excludes those three by
        # name rather than relying on this switch alone.
        #
        # CHOLMOD_SUPERNODAL=OFF is the fourth BLAS consumer, and the one that
        # decides whether CHOLMOD itself is in at all. CHOLMOD/CMakeLists
        # .txt:291-298 includes SuiteSparseBLAS *and* SuiteSparseLAPACK
        # unless it is off, and SuiteSparse_config/cmake_modules/
        # SuiteSparseLAPACK.cmake ends in `find_package ( LAPACK REQUIRED )`
        # as well. With it off, :293 adds -DNSUPERNODAL and CHOLMOD builds
        # its simplicial (up-looking LDL' and multifrontal LL') methods, which
        # are the ones that need no dense linear algebra. This is the
        # documented no-BLAS build: CHOLMOD's own User Guide says of BLAS and
        # LAPACK, at Doc/CHOLMOD_UserGuide.tex:306 and :310, "Not needed if
        # -DNSUPERNODAL is used".
        #
        # SUITESPARSE_USE_OPENMP=OFF. The option defaults to ON
        # (SuiteSparsePolicy.cmake:165) and SuiteSparse_config/CMakeLists
        # .txt:50-56 then calls find_package(OpenMP COMPONENTS C GLOBAL),
        # which is not a REQUIRED lookup - but if the NDK's clang does expose
        # a libomp runtime, OpenMP::OpenMP_C lands in the static archives'
        # link interface and every consumer in this prefix would inherit a
        # -fopenmp it cannot satisfy. Nothing in this tree ships an OpenMP
        # runtime, and every library here is single-threaded, so ask for the
        # serial build rather than depend on what FindOpenMP happens to find.
        #
        # SUITESPARSE_USE_PYTHON=OFF, default ON (SuiteSparsePolicy.cmake:169).
        # It only affects SPEX, and a Python extension module for a target
        # library is not something this prefix can host.
        #
        # Not passed, deliberately:
        #   * SUITESPARSE_DEMOS - already OFF upstream
        #     (SuiteSparsePolicy.cmake:175). Every add_executable in the tree
        #     is inside an `if ( SUITESPARSE_DEMOS )` or an
        #     `if ( BUILD_TESTING )` guard, so no demo or test program is
        #     built.
        #   * SUITESPARSE_USE_FORTRAN - defaults to ON but is a
        #     check_language probe (SuiteSparsePolicy.cmake:321, and the
        #     check_language ( Fortran ) at :324) that finds no Fortran
        #     compiler and sets SUITESPARSE_HAS_FORTRAN OFF. Only the demo .f
        #     files would need one, and demos are off.
        #   * SUITESPARSE_USE_CUDA - likewise defaults ON (:378), probed with
        #     check_language ( CUDA ) at :383 and not found.
        cmake -S . -B build $CMAKE_FLAGS \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DSUITESPARSE_ENABLE_PROJECTS="suitesparse_config;btf;amd;camd;ccolamd;colamd;cholmod;cxsparse;klu;ldl;mongoose;rbio;spex" \
            -DSUITESPARSE_REQUIRE_BLAS=OFF \
            -DCHOLMOD_SUPERNODAL=OFF \
            -DSUITESPARSE_USE_OPENMP=OFF \
            -DSUITESPARSE_USE_PYTHON=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})
