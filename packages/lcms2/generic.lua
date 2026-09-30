require("zlib")
require("libjpeg-turbo")
require("libtiff")
require("lcms2@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/lcms2/* .
        # Static library with the JPEG and TIFF plug-ins, found through this
        # prefix's pkg-config path, plus zlib for the utilities. The tiff and
        # jpeg utilities are host programs and stay off.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --with-jpeg="$PREFIX" --with-tiff="$PREFIX" --without-python --disable-utils
        touch aclocal.m4 configure config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1
        make install
    ]]
})
