-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe.
require("flex@native")
require("bison@native")
require("libnl-3@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libnl-3/* .
        # Bionic has no libpthread at all: the NDK sysroot ships no
        # libpthread.a or libpthread.so for any API level (checked
        # r28b), and configure.ac:119 does
        #   AC_CHECK_LIB([pthread], [pthread_mutex_lock], [],
        #                 AC_MSG_ERROR([libpthread is required]))
        # which is a hard error, not a warning. --disable-pthreads is the
        # upstream switch for that: it defines DISABLE_PTHREADS, which
        # turns the internal NL_LOCK/NL_RW_LOCK helpers into no-ops. The
        # library still builds and works; it just stops guarding its own
        # caches against concurrent callers.
        # Verified: `find` over the whole NDK sysroot for `libpthread*`
        # returns nothing, and `aarch64-linux-android24-clang ... -lpthread`
        # fails with `ld.lld: error: unable to find library -lpthread`. There
        # is no stub at any API level.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --enable-cli=no --disable-pthreads
        touch aclocal.m4 configure include/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
