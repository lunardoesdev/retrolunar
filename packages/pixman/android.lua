-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe. Only the 32-bit ARM SIMD
-- switches below are Android-specific; every other line is generic.lua's.
require("pixman@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/pixman/* .
        # Android-only: pixman's 32-bit ARM runtime CPU detection needs a
        # header the NDK does not ship.
        #
        # pixman-arm.c:96 selects an Android branch that does
        # `#include <cpu-features.h>` and calls android_getCpuFamily() /
        # android_getCpuFeatures(). That header is AOSP's, not Bionic's: it is
        # absent from every include directory of the NDK r28b sysroot
        # (a `find` for cpu-features* over sysroot/ returns zero hits). When
        # meson enables either 32-bit ARM path - arm-simd-test.S or
        # neon-test.S, both of which the NDK's armv7a clang compiles cleanly -
        # meson.build:298/315 defines USE_ARM_SIMD / USE_ARM_NEON, and
        # pixman-arm.c:36's guard admits the file, so the build dies on the
        # missing header. Verified directly: compiling pixman-arm.c with
        # -DUSE_ARM_NEON against armv7a-linux-androideabi35-clang gives
        # "fatal error: 'cpu-features.h' file not found" at pixman-arm.c:98.
        #
        # Upstream's own answer is the cpu-features-path option
        # (meson.options:81-85), which expects a local copy of AOSP's
        # cpu-features.c/h. This prefix has no such source package, and
        # vendoring one would mean shipping a patched upstream tree, which
        # AGENTS.md forbids. So the two paths are turned off instead.
        #
        # This costs nothing on aarch64: meson.build:290/306/322 gate arm-simd,
        # neon and a64-neon on host_machine.cpu_family(), and our Android cross
        # files say 'aarch64' for the 64-bit systems and 'arm' for armv7a.
        # On aarch64 only a64-neon can turn on, it defines USE_ARM_A64_NEON
        # (meson.build:330) rather than USE_ARM_NEON, and pixman-arm.c:36 does
        # not test for it, so aarch64 never reaches the cpu-features branch and
        # keeps full NEON. Only armv7a loses the SIMD and NEON fast paths and
        # falls back to the generic C implementations.
        meson setup build $MESON_FLAGS -Dbuildtype=release -Ddefault_library=static \
            -Dtests=disabled -Ddemos=disabled -Dlibpng=disabled -Dgtk=disabled \
            -Dopenmp=disabled -Darm-simd=disabled -Dneon=disabled
        ninja -C build --parallel 1
        ninja -C build install
    ]]
})