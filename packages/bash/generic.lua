require("bash@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/bash/* .
        # bash 5.3 typedefs `bool` itself: needs pre-C23 (NDK clang
        # defaults to C23 where bool is a keyword).
        export CC="$CC -std=gnu17"
        export CC_FOR_BUILD="cc -std=gnu17"
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-bash-malloc --disable-nls
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
