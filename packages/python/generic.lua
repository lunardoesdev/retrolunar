require("python@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/python/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --build=x86_64-pc-linux-gnu --with-build-python=python3 --disable-shared --without-ensurepip --disable-test-modules --without-readline --without-remote-debug
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' -o -name 'Makefile.pre.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
