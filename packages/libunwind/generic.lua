require("libunwind@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libunwind/* .
        # Static with PIC. 1.8.3 has no libelf and no LLVM probe at all
        # (grep finds neither string outside config.guess/config.sub/
        # ltmain.sh), so the built-in frame-based unwinder is what we get;
        # that is the library's own code, not a fallback path. The test
        # suite links -static and dlopen and would have to run on the
        # target, and the man pages need latex2man, so both are off.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-tests --disable-documentation
        touch aclocal.m4 configure include/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
