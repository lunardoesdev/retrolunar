require("m4")
require("autoconf@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/autoconf/* .
        ./configure --prefix="$OUT" --host=aarch64-linux-android
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j$(nproc 2>/dev/null || echo 4)
        make install
    ]]
})
