-- aarch64-linux-android21: NDK cross toolchain (from env.sh article).
-- PREFIX/OUT contract: PREFIX is the search path (nest prefix),
-- OUT is the per-package stage dir. Install flags point at $OUT,
-- search flags at $PREFIX. setup runs first in each block: locates
-- the NDK, puts its wrappers on PATH, writes the cmake toolchain
-- and meson cross files into $WORK.
return system({
    env = {
        CC = "aarch64-linux-android21-clang",
        CXX = "aarch64-linux-android21-clang++",
        AR = "llvm-ar",
        RANLIB = "llvm-ranlib",
        LD = "ld.lld",
        AS = "$CC",
        STRIP = "llvm-strip",
        OBJCOPY = "llvm-objcopy",
        READELF = "llvm-readelf",
        NM = "llvm-nm",
        OBJDUMP = "llvm-objdump",

        SYSROOT = "$TOOLCHAIN/sysroot",

        CFLAGS = "-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include",
        CXXFLAGS = "-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include",
        LDFLAGS = "-L$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib -Wl,--undefined-version",

        PKG_CONFIG_LIBDIR = "$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig",
        PKG_CONFIG_PATH = "",

        AUTOCONF_CONFIGURE_FLAGS = "--host=aarch64-linux-android --prefix=$OUT",

        CMAKE_TOOLCHAIN_FILE = "$WORK/aarch64-linux-android21-toolchain.cmake",
        CMAKE_PREFIX_PATH = "$PREFIX",
        CMAKE_FLAGS = "-DCMAKE_TOOLCHAIN_FILE=$WORK/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX",

        MESON_CROSS_FILE = "$WORK/crossfile-aarch64-android21.ini",
        MESON_FLAGS = "--prefix=$OUT --cross-file $WORK/crossfile-aarch64-android21.ini",

        CARGO_BUILD_TARGET = "aarch64-linux-android",
        CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = "aarch64-linux-android21-clang",
        CARGO_TARGET_AARCH64_LINUX_ANDROID_AR = "llvm-ar",
        PKG_CONFIG_ALLOW_CROSS = "1",
    },
    setup = [[
        : "${ANDROID_HOME:?set ANDROID_HOME to an Android SDK with an NDK}"
        _ndk_ver="$(for _ndk_cand in "$ANDROID_HOME/ndk"/*; do
          [ -d "$_ndk_cand" ] || continue
          printf '%s\n' "${_ndk_cand##*/}"
        done | sort -V | tail -1)"
        if [ -z "$_ndk_ver" ]; then
          echo "aarch64-android21: no NDK under $ANDROID_HOME/ndk" >&2
          unset _ndk_ver _ndk_cand
          exit 1
        fi
        NDK="$ANDROID_HOME/ndk/$_ndk_ver"
        unset _ndk_ver _ndk_cand
        export NDK
        TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
        export TOOLCHAIN
        PATH="$TOOLCHAIN/bin:$PATH"
        export PATH
        SYSROOT="$TOOLCHAIN/sysroot"
        export SYSROOT
        CC_aarch64_linux_android="$CC"
        export CC_aarch64_linux_android
        CFLAGS_aarch64_linux_android="$CFLAGS"
        export CFLAGS_aarch64_linux_android
        CXX_aarch64_linux_android="$CXX"
        export CXX_aarch64_linux_android
        CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
        export CXXFLAGS_aarch64_linux_android
        cat > "$WORK/aarch64-linux-android21-toolchain.cmake" <<'EOF'
        set(CMAKE_SYSTEM_NAME Linux)
        set(CMAKE_SYSTEM_PROCESSOR "aarch64")
        if(NOT CMAKE_C_COMPILER)
          set(CMAKE_C_COMPILER "$ENV{CC}" CACHE FILEPATH "C compiler" FORCE)
        endif()
        if(NOT CMAKE_CXX_COMPILER)
          set(CMAKE_CXX_COMPILER "$ENV{CXX}" CACHE FILEPATH "C++ compiler" FORCE)
        endif()
        set(CMAKE_AR "$ENV{AR}" CACHE FILEPATH "archiver" FORCE)
        set(CMAKE_RANLIB "$ENV{RANLIB}" CACHE FILEPATH "ranlib" FORCE)
        set(CMAKE_STRIP "$ENV{STRIP}" CACHE FILEPATH "strip" FORCE)
        set(CMAKE_READELF "$ENV{READELF}" CACHE FILEPATH "readelf" FORCE)
        set(CMAKE_OBJDUMP "$ENV{OBJDUMP}" CACHE FILEPATH "objdump" FORCE)
        set(CMAKE_OBJCOPY "$ENV{OBJCOPY}" CACHE FILEPATH "objcopy" FORCE)
        set(CMAKE_NM "$ENV{NM}" CACHE FILEPATH "nm" FORCE)
        set(CMAKE_ASM_COMPILER "$ENV{AS}" CACHE FILEPATH "assembler" FORCE)
        set(CMAKE_LINKER "$ENV{LD}" CACHE FILEPATH "linker" FORCE)
        set(CMAKE_SYSROOT "$ENV{SYSROOT}")
        set(CMAKE_INSTALL_PREFIX "$ENV{PREFIX}" CACHE PATH "install prefix")
        set(CMAKE_FIND_ROOT_PATH "$ENV{PREFIX};$ENV{SYSROOT}")
        set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
        set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
        set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
        set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
        EOF
        cat > "$WORK/crossfile-aarch64-android21.ini" <<'EOF'
        [binaries]
        c = 'aarch64-linux-android21-clang'
        cpp = 'aarch64-linux-android21-clang++'
        ar = 'llvm-ar'
        strip = 'llvm-strip'
        ld = 'ld.lld'
        pkgconfig = 'pkg-config'
        [host_machine]
        system = 'android'
        cpu_family = 'aarch64'
        cpu = 'aarch64'
        endian = 'little'
        [properties]
        EOF
    ]],
})
