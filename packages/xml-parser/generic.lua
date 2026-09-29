require("expat")
require("perl@native")
require("xml-parser@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/xml-parser/. .
        # XML::Parser is an XS module, so the split is:
        #   - Makefile.PL and xsubpp are build-time generators and must run
        #     under a NATIVE perl, taken from $NATIVE_PREFIX/bin (the same
        #     shape as gperf@native in packages/bison);
        #   - the XS sources they emit are then compiled by the Android
        #     cross-compiler into a target .so.
        # The loader exports NATIVE_PREFIX and puts it on PATH, so `perl` here
        # is the native one; nothing is hardcoded.
        #
        # The generated Makefile records the native perl's own -march/-O flags
        # and its CORE include dir, both x86-64, so OPTIMIZE/perl_inc are reset
        # to target-appropriate values on the make line. The libc-only feature
        # macros that perl's CORE/config.h carries are turned off for the same
        # reason: Bionic has no crypt.h or shadow.h, and Bionic's <sys/sem.h>
        # already provides union semun, which perl.h would otherwise redefine.
        export PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"
        perl Makefile.PL EXPATINCPATH=$PREFIX/include EXPATLIBPATH=$PREFIX/lib
        make CC="$CC" LD="$LD" OPTIMIZE="-O2 -fPIC" \
            perl_inc="$NATIVE_PREFIX/lib/perl5/5.44/core_perl" \
            to_cflags="-D_I_CRYPT_H=0 -DHAS_UNION_SEMUN=1"
        make install
    ]]
})
