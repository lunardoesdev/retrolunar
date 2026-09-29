require("zlib")
require("libpng@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libpng/* .
        # mingw zlib installs as libzlib (not libz), but configure's
        # zlib probe hardcodes -lz (LIBS env can't override it: the
        # probe prepends its own -lz, and a missing -l is a hard error).
        # Alias the names in $PREFIX so -lz resolves; harmless additive
        # symlinks, benefits any later -lz user too.
        for _f in "$PREFIX/lib"/libzlib.*; do
          [ -f "$_f" ] || continue
          _ext="${_f##*libzlib}"
          [ -f "$PREFIX/lib/libz$_ext" ] || ln -s "libzlib$_ext" "$PREFIX/lib/libz$_ext"
        done
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-zlib-prefix="$PREFIX"
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
