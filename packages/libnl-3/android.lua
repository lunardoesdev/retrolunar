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
        # Bionic and glibc disagree about who owns the in_addr_t typedef,
        # and libnl's own private headers lose the race. libnl compiles with
        # `-I$(srcdir)/include/linux-private` (Makefile.am:350), which comes
        # before the sysroot on the search path, so `#include <netinet/in.h>`
        # -- which libnl's include/base/nl-base-utils.h:20 does -- pulls
        # Bionic's netinet/in.h, which includes <linux/in.h> (netinet/in.h:39),
        # and THAT resolves to libnl's copy rather than the NDK's.
        # libnl's include/linux-private/linux/in.h defines `struct in_addr`
        # (line 92) but never typedefs in_addr_t; the NDK's
        # <linux/in.h> would have reached <bits/in_addr.h>, which does
        # (`typedef uint32_t in_addr_t`, bits/in_addr.h:40). glibc has no such
        # problem because its own netinet/in.h:30 carries the typedef, so
        # this is Android-only. Without it, arpa/inet.h:40 fails with
        # "unknown type name 'in_addr_t'" and libnl-3 does not compile at all.
        # This is a build-time define only: it is not baked into the shipped
        # headers, and consumers are unaffected because nothing shadows
        # <linux/in.h> outside libnl's own tree. It restores exactly the
        # definition Bionic would have supplied.
        touch aclocal.m4 configure include/config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 CFLAGS="$CFLAGS -Din_addr_t=uint32_t"
        make install
    ]]
})
