require("glad@source")
-- GLAD2 has no build system at all: it is a Python package, and the C that
-- actually installs is whatever `python3 -m glad` writes out. The generator
-- therefore needs a HOST interpreter, which on every cross system is the one
-- in the native prefix: the loader puts $NATIVE_PREFIX/bin at the front of
-- PATH for every block, so a bare `python3` here is always the native one and
-- never the target's. The three requires are `@native` for that reason and
-- are the whole answer to "where does the generated source come from".
--
-- NOTE for the reviewer: as of this writing all three of these packages are
-- REJECTed at stage 2 and there is no python3 in the native prefix, so this
-- recipe cannot yet run. That is a dependency blocker, not a recipe defect;
-- packages/glad/stage1.md records it and the per-system rows are WILL NOT
-- BUILD because of it.
require("python@native")
-- The generator imports Jinja2 (glad/generator/__init__.py:7) and Jinja2
-- imports MarkupSafe. Both are pure-Python recipes in this tree - markupsafe
-- does not build its optional _speedups C accelerator and falls back to its
-- pure-Python module - so @native copies are architecture-independent and
-- land in the native interpreter's own site-packages, which is where it looks.
require("jinja2@native")
require("markupsafe@native")

return recipe({
    build = [[
        cp -r $NESTDIR/source/glad/* .
        # --reproducible is load-bearing, not cosmetic. Without it the CLI
        # installs glad.opener.URLOpener and fetches gl.xml from
        # raw.githubusercontent.com (glad/__main__.py:149-153), which is
        # network access at build time and therefore forbidden here. With it
        # the CLI installs glad.files.StaticFileOpener, whose urlopen()
        # discards the URL and opens the same basename out of glad/files/
        # instead (glad/files/__init__.py:51-58). Every registry the GL and
        # EGL specifications need is vendored in the release - glad/files/
        # holds gl.xml, egl.xml, glx.xml, wgl.xml, vk.xml, khrplatform.h and
        # eglplatform.h - so generation is fully offline, and it also pins the
        # timestamp to '-' so the output is byte-stable across runs.
        #
        # ARGUMENT ORDER IS LOAD-BEARING. The global options
        # (--out-path/--api/--reproducible) live on the top-level parser
        # (glad/__main__.py:122) but the generator's own options, --loader
        # among them, live on the `c` SUBCOMMAND
        # (glad/__main__.py:134-135, glad/config.py:288-296). argparse matches
        # the subcommand token before the subparser takes over, so `c` has to
        # come first and `--loader` after it. Putting --loader before the
        # subcommand aborts with "unrecognized arguments: --loader" before a
        # single file is written.
        #
        # --api=gl:core=3.3,gles2,egl covers what these targets can run:
        # desktop GL core for x86_64-mingw and clang-native, GLES2 for Android,
        # and EGL - see the next paragraph for why EGL is not optional here.
        # Both GL versions are pinned explicitly; "no version" means *latest*
        # (glad/__main__.py:88-96).
        #
        # `egl` IS IN THE API LIST BECAUSE --loader NEEDS IT. The built-in
        # loader includes loader/<api>.c for each selected API
        # (glad/generator/c/templates/base_template.c:185-191), and
        # loader/gles2.c:17 does an unconditional `#include <glad/egl.h>` to
        # pick up EGLDisplay and PFNEGLGETPROCADDRESSPROC. That header is only
        # generated when egl is one of the requested APIs, so with
        # `--api=gl:core=3.3,gles2` the generated src/gles2.c cannot compile:
        # "fatal error: 'glad/egl.h' file not found". Asking glad for egl
        # makes it generate glad/egl.h and src/egl.c from its own vendored
        # glad/files/egl.xml and eglplatform.h, so nothing outside this tree is
        # needed for it.
        #
        # The alternative, compiling gles2.c with -DGLAD_GLES2_USE_SYSTEM_EGL,
        # is NOT usable here: that arm is `#include <EGL/egl.h>`
        # (loader/gles2.c:13-14) and __eglMustCastToProperFunctionPointerType is
        # declared by that header. The NDK sysroot does ship EGL/egl.h, but the
        # mingw sysroot has no EGL/ directory at all (verified), so that is an
        # Android-only fact and would break x86_64-mingw. It would also be a
        # compile definition every consumer has to replicate.
        python3 -m glad --out-path=glad-out --reproducible --api=gl:core=3.3,gles2,egl c --loader
        mkdir -p obj $OUT/lib $OUT/include
        # The generated sources are plain C and include their own headers by
        # the installed path (<glad/gl.h>, base_template.c:11), so they need
        # the generated include tree on the search path and nothing else: no
        # OpenGL headers, no X11, and no *system* EGL headers. The loader adds
        # <dlfcn.h> on non-Windows (templates/loader/library.c:9), which
        # Bionic has from API 21, while GLAD_PLATFORM_WIN32 makes mingw use
        # <windows.h> and LoadLibraryA instead.
        $CC $CFLAGS -Iglad-out/include -c glad-out/src/gl.c -o obj/gl.o
        $CC $CFLAGS -Iglad-out/include -c glad-out/src/gles2.c -o obj/gles2.o
        $CC $CFLAGS -Iglad-out/include -c glad-out/src/egl.c -o obj/egl.o
        $AR rcs $OUT/lib/libglad.a obj/gl.o obj/gles2.o obj/egl.o
        $RANLIB $OUT/lib/libglad.a
        # This also installs glad's own copies of the Khronos platform
        # headers the generated headers need (KHR/khrplatform.h and
        # EGL/eglplatform.h), written by
        # glad/generator/c/__init__.py:_add_additional_headers. Worth knowing:
        # the EGL/eglplatform.h that lands in the shared prefix could shadow a
        # real system one for a consumer that also links a system EGL.
        cp -r glad-out/include/. $OUT/include/
        # Upstream ships no .pc and no CMake package config anywhere in the
        # tree - this is a generator, it has nothing to describe - so one is
        # written here, as packages/lua/generic.lua does. No compile
        # definition is needed by consumers: everything glad needs, it
        # generated itself.
        mkdir -p $OUT/lib/pkgconfig
        cat > $OUT/lib/pkgconfig/glad.pc <<EOF
        prefix=$PREFIX
        exec_prefix=\${prefix}
        libdir=\${exec_prefix}/lib
        includedir=\${prefix}/include
        Name: glad
        Description: Multi-API GL/GLES/EGL loader generated by glad
        Version: 2.0.8
        Libs: -L\${libdir} -lglad
        Cflags: -I\${includedir}
        EOF
    ]]
})