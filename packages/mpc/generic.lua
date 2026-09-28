require("gmp")
require("mpfr")
require("mpc@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/mpc/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --disable-static \
            --docdir="$OUT/share/doc/mpc-1.3.1"
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make -j1 install
        make -j1 install-html
    ]]
})
