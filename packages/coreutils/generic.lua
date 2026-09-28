require("acl")
require("coreutils@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/coreutils/* .
        # Procps and Psmisc provide these two commands separately.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-no-install-program=kill,uptime
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
