require("file@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/file/* .

        # magic/Makefile.am:366-371 branches on IS_CROSS_COMPILE
        # (configure.ac:237, test "$cross_compiling" = yes) and, when cross
        # compiling, uses a bare PATH lookup, `file${EXEEXT}`, instead of the
        # just-built target binary - so the target file is never executed and
        # the no-emulation rule is not at risk. What does fail is
        # magic/Makefile.am:377-384, which hard-fails unless that PATH `file`
        # reports exactly PACKAGE_VERSION, i.e. 5.46. The build host carries
        # file-5.48, so 5.48 != 5.46 and the build aborts. File 5.46 has no
        # configure switch to skip the database: its nine AC_ARG_ENABLE and
        # AC_ARG_WITH cover elf, elf-core, zlib, bzlib, xzlib, zstdlib, lzlib,
        # lrziplib, libseccomp, fsect-man5 and warnings, and `configure --help`
        # greps zero hits for magic.
        #
        # So a host file of the SAME version is required, and
        # packages/file/clang-native.lua is how this repo gets one: it builds
        # this identical 5.46 for the native system, so its bin/file lands in
        # $NATIVE_PREFIX/bin, which the loader puts first on PATH
        # (src/loader.lua:412-415), and the version check passes by
        # construction. That recipe must therefore be built BEFORE any target
        # build of file; the loader cannot express the ordering as a
        # dependency from here.
        #
        # It cannot be a require() on this side. @native resolves to
        # clang-native, and before clang-native.lua existed the loader fell
        # back to THIS file (src/loader.lua:199-201), so the recipe required
        # itself: `retrolunar install` died with "C stack overflow" at
        # src/loader.lua:104, because src/loader.lua has no module cache and
        # no cycle guard. Measured, not assumed. Every other @native in the
        # tree names a different package (gperf for bison and libseccomp, tcl
        # for expect, perl for intltool, flex and bison for libnl-3), which is
        # why none of them hit this - and why clang-native.lua, a genuinely
        # different recipe, is the fix rather than a self-reference.

        ./configure $AUTOCONF_CONFIGURE_FLAGS
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
    ]]
})
