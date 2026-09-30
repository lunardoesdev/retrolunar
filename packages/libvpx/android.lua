require("libvpx@source")

-- One recipe for every Android target: each Android system lists "android"
-- in its recipe_fallbacks, so this file is reached without a copy per
-- target. The tuple and the sysroot are system facts and come from the
-- environment: $TARGET_TRIPLET is this system's libvpx tuple and $SYSROOT
-- its NDK sysroot.
return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # Android needs an explicit --target: this hand-written configure
        # cannot infer Bionic from the host. The sysroot goes in
        # --extra-cflags on purpose: passed as -isystem it reorders libc++
        # before its own C headers and breaks <cstdint>.
        ./configure --prefix="$OUT" --target="$TARGET_TRIPLET" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared \
          --extra-cflags="--sysroot=$SYSROOT" \
          --extra-cxxflags="--sysroot=$SYSROOT"
        make -j1
        make install
    ]]
})
