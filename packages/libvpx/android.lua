require("libvpx@source")

-- One recipe for every Android target: each Android system lists "android"
-- in its recipe_fallbacks, so this file is reached without a copy per
-- target. The host machine and its sysroot come from the system.
return recipe({
    build = [[
        cp -r $NESTDIR/source/libvpx/* .
        # Android needs an explicit --target: this hand-written configure
        # cannot infer Bionic from the build machine. libvpx spells 64-bit
        # ARM "arm64" and 32-bit x86 "x86"; everything else is the host arch
        # as the system reports it.
        case "$HOST_ARCH" in
            aarch64) vpx_arch=arm64 ;;
            i686) vpx_arch=x86 ;;
            *) vpx_arch="$HOST_ARCH" ;;
        esac
        # The sysroot goes in --extra-cflags on purpose: passed as -isystem
        # it reorders libc++ before its own C headers and breaks <cstdint>.
        ./configure --prefix="$OUT" --target="$vpx_arch-$HOST_OS-gcc" \
          --disable-examples --disable-docs --disable-unit-tests \
          --disable-tools --enable-pic --enable-static --disable-shared \
          --extra-cflags="--sysroot=$SYSROOT" \
          --extra-cxxflags="--sysroot=$SYSROOT"
        make -j1
        make install
    ]]
})
