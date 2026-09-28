require("readline")
require("python@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/python/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-build-python=python3 --disable-shared --without-ensurepip --disable-test-modules
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' -o -name 'Makefile.pre.in' | xargs touch
        make
        make install
    ]]
})
