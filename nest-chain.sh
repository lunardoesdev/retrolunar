#!/bin/sh
set -eu
NESTDIR='/home/si/ond/git/retrolunar/nest'
PACKAGEDIR='/home/si/ond/git/retrolunar/packages'
mkdir -p "$NESTDIR/tmp"
# --- zlib@source ---
if [ -f $NESTDIR/source/.retrolunar-zlib ] && [ $NESTDIR/source/.retrolunar-zlib -nt $PACKAGEDIR/zlib/source.lua ]; then
  echo "skip zlib@source (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/source"
  RECIPEDIR="$PACKAGEDIR/zlib"
  SYSDIR="$PACKAGEDIR/source"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      mkdir -p dl
      if [ ! -f dl/zlib.tar.gz ]; then
        curl -fSL -C - -o dl/zlib.tar.gz "https://zlib.net/fossils/zlib-1.3.1.tar.gz" || curl -fSL -C - -o dl/zlib.tar.gz "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
      fi
      rm -rf src
      mkdir -p src
      tar -xzf dl/zlib.tar.gz -C src --strip-components=1
      mkdir -p $OUT/zlib
      cp -r src/* $OUT/zlib/
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/source"
  cp -rf "$OUT"/. "$NESTDIR/source/"
  touch $NESTDIR/source/.retrolunar-zlib
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- zlib@aarch64-android21 ---
if [ -f $NESTDIR/aarch64-android21/.retrolunar-zlib ] && [ $NESTDIR/aarch64-android21/.retrolunar-zlib -nt $PACKAGEDIR/zlib/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-zlib -nt $PACKAGEDIR/aarch64-android21/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-zlib -nt $PACKAGEDIR/aarch64-android21 ]; then
  echo "skip zlib@aarch64-android21 (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/aarch64-android21"
  RECIPEDIR="$PACKAGEDIR/zlib"
  SYSDIR="$PACKAGEDIR/aarch64-android21"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
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
      CC="aarch64-linux-android21-clang"
      export CC
      CXX="aarch64-linux-android21-clang++"
      export CXX
      AR="llvm-ar"
      export AR
      RANLIB="llvm-ranlib"
      export RANLIB
      LD="ld.lld"
      export LD
      STRIP="llvm-strip"
      export STRIP
      OBJCOPY="llvm-objcopy"
      export OBJCOPY
      READELF="llvm-readelf"
      export READELF
      NM="llvm-nm"
      export NM
      OBJDUMP="llvm-objdump"
      export OBJDUMP
      CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CFLAGS
      CXXFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CXXFLAGS
      LDFLAGS=""
      export LDFLAGS
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
      export PKG_CONFIG_LIBDIR
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_PATH
      AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android21-toolchain.cmake"
      export CMAKE_TOOLCHAIN_FILE
      CMAKE_PREFIX_PATH="$PREFIX"
      export CMAKE_PREFIX_PATH
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_CROSS_FILE
      MESON_FLAGS="--prefix=$OUT --cross-file $SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_FLAGS
      CARGO_BUILD_TARGET="aarch64-linux-android"
      export CARGO_BUILD_TARGET
      CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android21-clang"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
      CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="llvm-ar"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR
      RUSTFLAGS="-L $PREFIX/lib"
      export RUSTFLAGS
      PKG_CONFIG_ALLOW_CROSS="1"
      export PKG_CONFIG_ALLOW_CROSS
      CC_aarch64_linux_android="$CC"
      export CC_aarch64_linux_android
      CFLAGS_aarch64_linux_android="$CFLAGS"
      export CFLAGS_aarch64_linux_android
      CXX_aarch64_linux_android="$CXX"
      export CXX_aarch64_linux_android
      CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
      export CXXFLAGS_aarch64_linux_android
  
      cp -r $NESTDIR/source/zlib/* .
      cmake -S . -B build $CMAKE_FLAGS -DZLIB_BUILD_EXAMPLES=OFF
      cmake --build build -j$(nproc 2>/dev/null || echo 4)
      cmake --install build
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/aarch64-android21"
  cp -rf "$OUT"/. "$NESTDIR/aarch64-android21/"
  touch $NESTDIR/aarch64-android21/.retrolunar-zlib
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- libpng@source ---
if [ -f $NESTDIR/source/.retrolunar-libpng ] && [ $NESTDIR/source/.retrolunar-libpng -nt $PACKAGEDIR/libpng/source.lua ]; then
  echo "skip libpng@source (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/source"
  RECIPEDIR="$PACKAGEDIR/libpng"
  SYSDIR="$PACKAGEDIR/source"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      mkdir -p dl
      if [ ! -f dl/libpng.tar.gz ]; then
        curl -fSL -C - -o dl/libpng.tar.gz "https://download.sourceforge.net/libpng/libpng-1.6.48.tar.gz" || curl -fSL -C - -o dl/libpng.tar.gz "https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.48.tar.gz"
      fi
      rm -rf src
      mkdir -p src
      tar -xzf dl/libpng.tar.gz -C src --strip-components=1
      mkdir -p $OUT/libpng
      cp -r src/* $OUT/libpng/
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/source"
  cp -rf "$OUT"/. "$NESTDIR/source/"
  touch $NESTDIR/source/.retrolunar-libpng
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- libpng@aarch64-android21 ---
if [ -f $NESTDIR/aarch64-android21/.retrolunar-libpng ] && [ $NESTDIR/aarch64-android21/.retrolunar-libpng -nt $PACKAGEDIR/libpng/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-libpng -nt $PACKAGEDIR/aarch64-android21/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-libpng -nt $PACKAGEDIR/aarch64-android21 ]; then
  echo "skip libpng@aarch64-android21 (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/aarch64-android21"
  RECIPEDIR="$PACKAGEDIR/libpng"
  SYSDIR="$PACKAGEDIR/aarch64-android21"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
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
      CC="aarch64-linux-android21-clang"
      export CC
      CXX="aarch64-linux-android21-clang++"
      export CXX
      AR="llvm-ar"
      export AR
      RANLIB="llvm-ranlib"
      export RANLIB
      LD="ld.lld"
      export LD
      STRIP="llvm-strip"
      export STRIP
      OBJCOPY="llvm-objcopy"
      export OBJCOPY
      READELF="llvm-readelf"
      export READELF
      NM="llvm-nm"
      export NM
      OBJDUMP="llvm-objdump"
      export OBJDUMP
      CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CFLAGS
      CXXFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CXXFLAGS
      LDFLAGS=""
      export LDFLAGS
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
      export PKG_CONFIG_LIBDIR
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_PATH
      AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android21-toolchain.cmake"
      export CMAKE_TOOLCHAIN_FILE
      CMAKE_PREFIX_PATH="$PREFIX"
      export CMAKE_PREFIX_PATH
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_CROSS_FILE
      MESON_FLAGS="--prefix=$OUT --cross-file $SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_FLAGS
      CARGO_BUILD_TARGET="aarch64-linux-android"
      export CARGO_BUILD_TARGET
      CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android21-clang"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
      CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="llvm-ar"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR
      RUSTFLAGS="-L $PREFIX/lib"
      export RUSTFLAGS
      PKG_CONFIG_ALLOW_CROSS="1"
      export PKG_CONFIG_ALLOW_CROSS
      CC_aarch64_linux_android="$CC"
      export CC_aarch64_linux_android
      CFLAGS_aarch64_linux_android="$CFLAGS"
      export CFLAGS_aarch64_linux_android
      CXX_aarch64_linux_android="$CXX"
      export CXX_aarch64_linux_android
      CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
      export CXXFLAGS_aarch64_linux_android
  
      export CPPFLAGS="-I$PREFIX/include"
      export LDFLAGS="-L$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib"
      cp -r $NESTDIR/source/libpng/* .
      ./configure $AUTOCONF_CONFIGURE_FLAGS --with-zlib-prefix="$PREFIX"
      make -j$(nproc 2>/dev/null || echo 4)
      make install
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/aarch64-android21"
  cp -rf "$OUT"/. "$NESTDIR/aarch64-android21/"
  touch $NESTDIR/aarch64-android21/.retrolunar-libpng
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- freetype@source ---
if [ -f $NESTDIR/source/.retrolunar-freetype ] && [ $NESTDIR/source/.retrolunar-freetype -nt $PACKAGEDIR/freetype/source.lua ]; then
  echo "skip freetype@source (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/source"
  RECIPEDIR="$PACKAGEDIR/freetype"
  SYSDIR="$PACKAGEDIR/source"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      mkdir -p dl
      if [ ! -f dl/freetype.tar.gz ]; then
        curl -fSL -C - -o dl/freetype.tar.gz "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.gz" || curl -fSL -C - -o dl/freetype.tar.gz "https://github.com/freetype/freetype/archive/refs/tags/VER-2-13-3.tar.gz"
      fi
      rm -rf src
      mkdir -p src
      tar -xzf dl/freetype.tar.gz -C src --strip-components=1
      mkdir -p $OUT/freetype
      cp -r src/* $OUT/freetype/
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/source"
  cp -rf "$OUT"/. "$NESTDIR/source/"
  touch $NESTDIR/source/.retrolunar-freetype
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- freetype@aarch64-android21 ---
if [ -f $NESTDIR/aarch64-android21/.retrolunar-freetype ] && [ $NESTDIR/aarch64-android21/.retrolunar-freetype -nt $PACKAGEDIR/freetype/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-freetype -nt $PACKAGEDIR/aarch64-android21/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-freetype -nt $PACKAGEDIR/aarch64-android21 ]; then
  echo "skip freetype@aarch64-android21 (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/aarch64-android21"
  RECIPEDIR="$PACKAGEDIR/freetype"
  SYSDIR="$PACKAGEDIR/aarch64-android21"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
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
      CC="aarch64-linux-android21-clang"
      export CC
      CXX="aarch64-linux-android21-clang++"
      export CXX
      AR="llvm-ar"
      export AR
      RANLIB="llvm-ranlib"
      export RANLIB
      LD="ld.lld"
      export LD
      STRIP="llvm-strip"
      export STRIP
      OBJCOPY="llvm-objcopy"
      export OBJCOPY
      READELF="llvm-readelf"
      export READELF
      NM="llvm-nm"
      export NM
      OBJDUMP="llvm-objdump"
      export OBJDUMP
      CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CFLAGS
      CXXFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CXXFLAGS
      LDFLAGS=""
      export LDFLAGS
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
      export PKG_CONFIG_LIBDIR
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_PATH
      AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android21-toolchain.cmake"
      export CMAKE_TOOLCHAIN_FILE
      CMAKE_PREFIX_PATH="$PREFIX"
      export CMAKE_PREFIX_PATH
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_CROSS_FILE
      MESON_FLAGS="--prefix=$OUT --cross-file $SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_FLAGS
      CARGO_BUILD_TARGET="aarch64-linux-android"
      export CARGO_BUILD_TARGET
      CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android21-clang"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
      CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="llvm-ar"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR
      RUSTFLAGS="-L $PREFIX/lib"
      export RUSTFLAGS
      PKG_CONFIG_ALLOW_CROSS="1"
      export PKG_CONFIG_ALLOW_CROSS
      CC_aarch64_linux_android="$CC"
      export CC_aarch64_linux_android
      CFLAGS_aarch64_linux_android="$CFLAGS"
      export CFLAGS_aarch64_linux_android
      CXX_aarch64_linux_android="$CXX"
      export CXX_aarch64_linux_android
      CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
      export CXXFLAGS_aarch64_linux_android
  
      export CPPFLAGS="-I$PREFIX/include -I$PREFIX/include/libpng16"
      export CFLAGS="-O2 -fPIC -I$PREFIX/include -I$PREFIX/include/libpng16 -DANDROID"
      cp -r $NESTDIR/source/freetype/* .
      meson setup build $MESON_FLAGS \
          -Dzlib=system -Dpng=enabled \
          -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
          -Dtests=disabled
      ninja -C build install
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/aarch64-android21"
  cp -rf "$OUT"/. "$NESTDIR/aarch64-android21/"
  touch $NESTDIR/aarch64-android21/.retrolunar-freetype
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- pngprobe@aarch64-android21 ---
if [ -f $NESTDIR/aarch64-android21/.retrolunar-pngprobe ] && [ $NESTDIR/aarch64-android21/.retrolunar-pngprobe -nt $PACKAGEDIR/pngprobe/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-pngprobe -nt $PACKAGEDIR/aarch64-android21/generic.lua ] && [ $NESTDIR/aarch64-android21/.retrolunar-pngprobe -nt $PACKAGEDIR/aarch64-android21 ]; then
  echo "skip pngprobe@aarch64-android21 (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/aarch64-android21"
  RECIPEDIR="$PACKAGEDIR/pngprobe"
  SYSDIR="$PACKAGEDIR/aarch64-android21"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
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
      CC="aarch64-linux-android21-clang"
      export CC
      CXX="aarch64-linux-android21-clang++"
      export CXX
      AR="llvm-ar"
      export AR
      RANLIB="llvm-ranlib"
      export RANLIB
      LD="ld.lld"
      export LD
      STRIP="llvm-strip"
      export STRIP
      OBJCOPY="llvm-objcopy"
      export OBJCOPY
      READELF="llvm-readelf"
      export READELF
      NM="llvm-nm"
      export NM
      OBJDUMP="llvm-objdump"
      export OBJDUMP
      CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CFLAGS
      CXXFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include"
      export CXXFLAGS
      LDFLAGS=""
      export LDFLAGS
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
      export PKG_CONFIG_LIBDIR
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_PATH
      AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/aarch64-linux-android21-toolchain.cmake"
      export CMAKE_TOOLCHAIN_FILE
      CMAKE_PREFIX_PATH="$PREFIX"
      export CMAKE_PREFIX_PATH
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/aarch64-linux-android21-toolchain.cmake -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_CROSS_FILE
      MESON_FLAGS="--prefix=$OUT --cross-file $SYSDIR/crossfile-aarch64-android21.ini"
      export MESON_FLAGS
      CARGO_BUILD_TARGET="aarch64-linux-android"
      export CARGO_BUILD_TARGET
      CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="aarch64-linux-android21-clang"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
      CARGO_TARGET_AARCH64_LINUX_ANDROID_AR="llvm-ar"
      export CARGO_TARGET_AARCH64_LINUX_ANDROID_AR
      RUSTFLAGS="-L $PREFIX/lib"
      export RUSTFLAGS
      PKG_CONFIG_ALLOW_CROSS="1"
      export PKG_CONFIG_ALLOW_CROSS
      CC_aarch64_linux_android="$CC"
      export CC_aarch64_linux_android
      CFLAGS_aarch64_linux_android="$CFLAGS"
      export CFLAGS_aarch64_linux_android
      CXX_aarch64_linux_android="$CXX"
      export CXX_aarch64_linux_android
      CXXFLAGS_aarch64_linux_android="$CXXFLAGS"
      export CXXFLAGS_aarch64_linux_android
  
      rm -f "$PREFIX/lib/libxcadd.a" "$PREFIX/lib/pkgconfig/xcadd.pc"
      rm -rf "$PREFIX/include/xcadd"
      mkdir -p src
      cat > Cargo.toml <<EOF
      [package]
      name = "pngprobe"
      version = "0.1.0"
      edition = "2021"
      [dependencies]
      libpng-sys = "=1.1.11"
EOF
      mkdir -p src
      cat > src/main.rs <<'EOF'
      fn main() {
          let ver = unsafe { libpng_sys::ffi::png_access_version_number() };
          println!("libpng version: {ver}");
          assert!(ver >= 10648, "unexpected libpng version: {ver}");
      }
EOF
      PNG_CONFIG="false" cargo build --release --target "$CARGO_BUILD_TARGET"
      if ! "$READELF" -d "target/$CARGO_BUILD_TARGET/release/pngprobe" | grep -q "libpng16"; then
        echo "error: pngprobe did not link libpng16 from \$PREFIX" >&2
        echo "--- readelf dump: ---" >&2
        "$READELF" -d "target/$CARGO_BUILD_TARGET/release/pngprobe" >&2 || true
        exit 1
      fi
      mkdir -p "$OUT/bin"
      cp "target/$CARGO_BUILD_TARGET/release/pngprobe" "$OUT/bin/"
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/aarch64-android21"
  cp -rf "$OUT"/. "$NESTDIR/aarch64-android21/"
  touch $NESTDIR/aarch64-android21/.retrolunar-pngprobe
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
