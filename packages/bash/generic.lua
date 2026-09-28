require("readline")
require("bash@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bash/* .
        # Bash's host-side helper uses a bool typedef; GCC 16 needs GNU17.
        CC_FOR_BUILD="cc" CFLAGS_FOR_BUILD="-std=gnu17" ./configure $AUTOCONF_CONFIGURE_FLAGS --without-bash-malloc --with-installed-readline
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
