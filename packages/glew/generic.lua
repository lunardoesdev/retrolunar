require("glew@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/glew/* .
        # GLEW 2.3.1 does ship a CMake build, at build/cmake/CMakeLists.txt,
        # but it cannot configure here and the hand-written makefile is used
        # instead. That CMakeLists.txt:39 is `find_package(OpenGL REQUIRED)`
        # and its result is linked into both library targets
        # (build/cmake/CMakeLists.txt:157-158); no Android sysroot, no mingw
        # sysroot and no glibc prefix in this tree offers a libGL for GLEW to
        # find. CMAKE_DISABLE_FIND_PACKAGE_OpenGL is not a way around it -
        # cmake documents that this applies only to non-REQUIRED find_package
        # calls. GLEW never actually needs one: it resolves GL through its
        # own function-pointer table, and the makefile never probes for GL at
        # all. That is the whole reason the makefile is the right build
        # system for this package here.
        #
        # The makefile picks a config/Makefile.<SYSTEM> by running
        # config.guess on the *build* host (Makefile:34-38); on this host
        # that always resolves to "linux", so config/Makefile.linux is what
        # every target uses. Those config files assign the compiler with a
        # plain `CC = cc` (config/Makefile.linux:2-3), and a makefile
        # assignment overrides the environment, so $CC would be ignored. A
        # make command-line variable beats a makefile one, which is how the
        # system's own toolchain is handed over.
        #
        # Only the static archive is built, and only that is installed, by
        # hand. Upstream's own install target is unusable here too: `install`
        # depends on `glew.lib`, which is both the static and the shared
        # library (Makefile:102,207), and the shared link (Makefile:122-123)
        # uses $(LD) with $(LDFLAGS.GL) = `-lGL -lX11`
        # (config/Makefile.linux:22). The default goal `all` additionally
        # builds glewinfo and visualinfo (Makefile:86,176-191), which are
        # host programs needing a GL display.
        #
        # LDFLAGS.GL= also stops `-lGL -lX11` reaching glew.pc, which is
        # generated with $(LDFLAGS.GL) substituted for @libgl@
        # (Makefile:153). Nothing in this prefix provides libGL or libX11, so
        # a consumer running `pkg-config --libs glew` must not be handed
        # either. GLEW_NO_GLU=-DGLEW_NO_GLU is the exact value Makefile:50
        # compares against, and it leaves @requireslib@ empty instead of
        # "glu" - there is no glu.pc in this prefix.
        #
        # STRIP= is upstream's own documented way to disable the archive strip
        # (Makefile:61-66); the default `strip` is the host strip, which must
        # never touch a cross archive. LIBDIR= is passed because
        # config/Makefile.linux:16-21 picks lib64 from `uname -m` of the
        # BUILD host, which would put a 32-bit target's archive under lib64.
        make -j1 glew.lib.static CC="$CC" AR="$AR" RANLIB="$RANLIB" STRIP= GLEW_DEST="$OUT" GLEW_PREFIX="$OUT" LIBDIR="$OUT/lib" LDFLAGS.GL= GLEW_NO_GLU=-DGLEW_NO_GLU
        mkdir -p $OUT/include/GL $OUT/lib/pkgconfig
        cp include/GL/glew.h include/GL/glxew.h include/GL/wglew.h include/GL/eglew.h $OUT/include/GL/
        cp lib/libGLEW.a $OUT/lib/
        cp glew.pc $OUT/lib/pkgconfig/
    ]]
})