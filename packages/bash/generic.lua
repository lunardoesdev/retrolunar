require("readline")
require("bash@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bash/* .
        # CC_FOR_BUILD/CFLAGS_FOR_BUILD: bash's host-side helper builtins/
        # mkbuiltins.c:23-27 includes <buildconf.h>, not <config.h>, whenever
        # CROSS_COMPILING is set (configure.ac:496 appends -DCROSS_COMPILING
        # via CROSS_COMPILE, folded in by builtins/Makefile.in:64). buildconf.h.in
        # has `#undef HAVE_C_BOOL` - "defining this implies a C23 environment" -
        # and never defines HAVE_STDBOOL_H, so bashansi.h:44 `typedef unsigned
        # char bool;` is what compiles. Against host gcc at its default
        # -std=gnu23 that is `error: 'bool' cannot be defined via 'typedef'`;
        # -std=gnu17 is clean.
        #
        # This is a CROSS-COMPILING fact, not an Android one, which is why it
        # lives here and not in android.lua: x86_64-mingw is also a cross build
        # (its system file sets --host=x86_64-w64-mingw32), it resolves through
        # this file, and it hits the identical error. clang-native is not
        # cross, so without CROSS_COMPILING the helper includes <config.h>
        # instead and compiles clean at either standard - which is why the flag
        # is harmless here and was never needed for the native build.
        CC_FOR_BUILD="cc" CFLAGS_FOR_BUILD="-std=gnu17" ./configure $AUTOCONF_CONFIGURE_FLAGS --without-bash-malloc --with-installed-readline
        touch aclocal.m4 configure config.h.in buildconf.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
