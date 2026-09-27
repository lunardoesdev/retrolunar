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
# --- zlib@x86_64-mingw ---
if [ -f $NESTDIR/x86_64-mingw/.retrolunar-zlib ] && [ $NESTDIR/x86_64-mingw/.retrolunar-zlib -nt $PACKAGEDIR/zlib/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-zlib -nt $PACKAGEDIR/x86_64-mingw/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-zlib -nt $PACKAGEDIR/x86_64-mingw ]; then
  echo "skip zlib@x86_64-mingw (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/x86_64-mingw"
  RECIPEDIR="$PACKAGEDIR/zlib"
  SYSDIR="$PACKAGEDIR/x86_64-mingw"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      # --- toolchain: mingw-w64 gcc + binutils ---
      CC="x86_64-w64-mingw32-gcc"
      CXX="x86_64-w64-mingw32-g++"
      AR="x86_64-w64-mingw32-ar"
      RANLIB="x86_64-w64-mingw32-ranlib"
      LD="x86_64-w64-mingw32-ld"
      STRIP="x86_64-w64-mingw32-strip"
      OBJCOPY="x86_64-w64-mingw32-objcopy"
      READELF="x86_64-w64-mingw32-readelf"
      NM="x86_64-w64-mingw32-nm"
      OBJDUMP="x86_64-w64-mingw32-objdump"
      WINDRES="x86_64-w64-mingw32-windres"
      export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP WINDRES

      # --- search paths: our prefix only, no sysroot ---
      # CPPFLAGS covers the autoconf probes ($CC -E without $CFLAGS).
      CPPFLAGS="-I$PREFIX/include"
      export CPPFLAGS
      CFLAGS="-O2"
      CFLAGS="$CFLAGS -I$PREFIX/include"
      CXXFLAGS="$CFLAGS"
      export CFLAGS CXXFLAGS
      # No -Wl,--undefined-version: that's ELF-only, ld for PE fails.
      LDFLAGS="-L$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
      export LDFLAGS
      # Look up .pc files in our prefix, ignore host ones.
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
      PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

      # --- build-system defaults: install into $OUT, find in $PREFIX ---
      AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-w64-mingw32"
      AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
      CMAKE_PREFIX_PATH="$PREFIX"
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-mingw.ini"
      MESON_FLAGS="--prefix=$OUT"
      MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
      export MESON_CROSS_FILE MESON_FLAGS

      # --- rust: windows target, same linker family, cross pkg-config ---
      CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR"
      RUSTFLAGS="-L $PREFIX/lib"
      PKG_CONFIG_ALLOW_CROSS="1"
      CC_x86_64_pc_windows_gnu="$CC"
      CFLAGS_x86_64_pc_windows_gnu="$CFLAGS"
      CXX_x86_64_pc_windows_gnu="$CXX"
      CXXFLAGS_x86_64_pc_windows_gnu="$CXXFLAGS"
      export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
      export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR RUSTFLAGS
      export PKG_CONFIG_ALLOW_CROSS
      export CC_x86_64_pc_windows_gnu CFLAGS_x86_64_pc_windows_gnu
      export CXX_x86_64_pc_windows_gnu CXXFLAGS_x86_64_pc_windows_gnu
  
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
  mkdir -p "$NESTDIR/x86_64-mingw"
  cp -rf "$OUT"/. "$NESTDIR/x86_64-mingw/"
  touch $NESTDIR/x86_64-mingw/.retrolunar-zlib
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
# --- libpng@x86_64-mingw ---
if [ -f $NESTDIR/x86_64-mingw/.retrolunar-libpng ] && [ $NESTDIR/x86_64-mingw/.retrolunar-libpng -nt $PACKAGEDIR/libpng/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-libpng -nt $PACKAGEDIR/x86_64-mingw/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-libpng -nt $PACKAGEDIR/x86_64-mingw ]; then
  echo "skip libpng@x86_64-mingw (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/x86_64-mingw"
  RECIPEDIR="$PACKAGEDIR/libpng"
  SYSDIR="$PACKAGEDIR/x86_64-mingw"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      # --- toolchain: mingw-w64 gcc + binutils ---
      CC="x86_64-w64-mingw32-gcc"
      CXX="x86_64-w64-mingw32-g++"
      AR="x86_64-w64-mingw32-ar"
      RANLIB="x86_64-w64-mingw32-ranlib"
      LD="x86_64-w64-mingw32-ld"
      STRIP="x86_64-w64-mingw32-strip"
      OBJCOPY="x86_64-w64-mingw32-objcopy"
      READELF="x86_64-w64-mingw32-readelf"
      NM="x86_64-w64-mingw32-nm"
      OBJDUMP="x86_64-w64-mingw32-objdump"
      WINDRES="x86_64-w64-mingw32-windres"
      export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP WINDRES

      # --- search paths: our prefix only, no sysroot ---
      # CPPFLAGS covers the autoconf probes ($CC -E without $CFLAGS).
      CPPFLAGS="-I$PREFIX/include"
      export CPPFLAGS
      CFLAGS="-O2"
      CFLAGS="$CFLAGS -I$PREFIX/include"
      CXXFLAGS="$CFLAGS"
      export CFLAGS CXXFLAGS
      # No -Wl,--undefined-version: that's ELF-only, ld for PE fails.
      LDFLAGS="-L$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
      export LDFLAGS
      # Look up .pc files in our prefix, ignore host ones.
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
      PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

      # --- build-system defaults: install into $OUT, find in $PREFIX ---
      AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-w64-mingw32"
      AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
      CMAKE_PREFIX_PATH="$PREFIX"
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-mingw.ini"
      MESON_FLAGS="--prefix=$OUT"
      MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
      export MESON_CROSS_FILE MESON_FLAGS

      # --- rust: windows target, same linker family, cross pkg-config ---
      CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR"
      RUSTFLAGS="-L $PREFIX/lib"
      PKG_CONFIG_ALLOW_CROSS="1"
      CC_x86_64_pc_windows_gnu="$CC"
      CFLAGS_x86_64_pc_windows_gnu="$CFLAGS"
      CXX_x86_64_pc_windows_gnu="$CXX"
      CXXFLAGS_x86_64_pc_windows_gnu="$CXXFLAGS"
      export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
      export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR RUSTFLAGS
      export PKG_CONFIG_ALLOW_CROSS
      export CC_x86_64_pc_windows_gnu CFLAGS_x86_64_pc_windows_gnu
      export CXX_x86_64_pc_windows_gnu CXXFLAGS_x86_64_pc_windows_gnu
  
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
  mkdir -p "$NESTDIR/x86_64-mingw"
  cp -rf "$OUT"/. "$NESTDIR/x86_64-mingw/"
  touch $NESTDIR/x86_64-mingw/.retrolunar-libpng
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
# --- freetype@x86_64-mingw ---
if [ -f $NESTDIR/x86_64-mingw/.retrolunar-freetype ] && [ $NESTDIR/x86_64-mingw/.retrolunar-freetype -nt $PACKAGEDIR/freetype/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-freetype -nt $PACKAGEDIR/x86_64-mingw/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-freetype -nt $PACKAGEDIR/x86_64-mingw ]; then
  echo "skip freetype@x86_64-mingw (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/x86_64-mingw"
  RECIPEDIR="$PACKAGEDIR/freetype"
  SYSDIR="$PACKAGEDIR/x86_64-mingw"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      # --- toolchain: mingw-w64 gcc + binutils ---
      CC="x86_64-w64-mingw32-gcc"
      CXX="x86_64-w64-mingw32-g++"
      AR="x86_64-w64-mingw32-ar"
      RANLIB="x86_64-w64-mingw32-ranlib"
      LD="x86_64-w64-mingw32-ld"
      STRIP="x86_64-w64-mingw32-strip"
      OBJCOPY="x86_64-w64-mingw32-objcopy"
      READELF="x86_64-w64-mingw32-readelf"
      NM="x86_64-w64-mingw32-nm"
      OBJDUMP="x86_64-w64-mingw32-objdump"
      WINDRES="x86_64-w64-mingw32-windres"
      export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP WINDRES

      # --- search paths: our prefix only, no sysroot ---
      # CPPFLAGS covers the autoconf probes ($CC -E without $CFLAGS).
      CPPFLAGS="-I$PREFIX/include"
      export CPPFLAGS
      CFLAGS="-O2"
      CFLAGS="$CFLAGS -I$PREFIX/include"
      CXXFLAGS="$CFLAGS"
      export CFLAGS CXXFLAGS
      # No -Wl,--undefined-version: that's ELF-only, ld for PE fails.
      LDFLAGS="-L$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
      export LDFLAGS
      # Look up .pc files in our prefix, ignore host ones.
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
      PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

      # --- build-system defaults: install into $OUT, find in $PREFIX ---
      AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-w64-mingw32"
      AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
      CMAKE_PREFIX_PATH="$PREFIX"
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-mingw.ini"
      MESON_FLAGS="--prefix=$OUT"
      MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
      export MESON_CROSS_FILE MESON_FLAGS

      # --- rust: windows target, same linker family, cross pkg-config ---
      CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR"
      RUSTFLAGS="-L $PREFIX/lib"
      PKG_CONFIG_ALLOW_CROSS="1"
      CC_x86_64_pc_windows_gnu="$CC"
      CFLAGS_x86_64_pc_windows_gnu="$CFLAGS"
      CXX_x86_64_pc_windows_gnu="$CXX"
      CXXFLAGS_x86_64_pc_windows_gnu="$CXXFLAGS"
      export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
      export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR RUSTFLAGS
      export PKG_CONFIG_ALLOW_CROSS
      export CC_x86_64_pc_windows_gnu CFLAGS_x86_64_pc_windows_gnu
      export CXX_x86_64_pc_windows_gnu CXXFLAGS_x86_64_pc_windows_gnu
  
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
  mkdir -p "$NESTDIR/x86_64-mingw"
  cp -rf "$OUT"/. "$NESTDIR/x86_64-mingw/"
  touch $NESTDIR/x86_64-mingw/.retrolunar-freetype
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- pngprobe@x86_64-mingw ---
if [ -f $NESTDIR/x86_64-mingw/.retrolunar-pngprobe ] && [ $NESTDIR/x86_64-mingw/.retrolunar-pngprobe -nt $PACKAGEDIR/pngprobe/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-pngprobe -nt $PACKAGEDIR/x86_64-mingw/generic.lua ] && [ $NESTDIR/x86_64-mingw/.retrolunar-pngprobe -nt $PACKAGEDIR/x86_64-mingw ]; then
  echo "skip pngprobe@x86_64-mingw (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/x86_64-mingw"
  RECIPEDIR="$PACKAGEDIR/pngprobe"
  SYSDIR="$PACKAGEDIR/x86_64-mingw"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      # --- toolchain: mingw-w64 gcc + binutils ---
      CC="x86_64-w64-mingw32-gcc"
      CXX="x86_64-w64-mingw32-g++"
      AR="x86_64-w64-mingw32-ar"
      RANLIB="x86_64-w64-mingw32-ranlib"
      LD="x86_64-w64-mingw32-ld"
      STRIP="x86_64-w64-mingw32-strip"
      OBJCOPY="x86_64-w64-mingw32-objcopy"
      READELF="x86_64-w64-mingw32-readelf"
      NM="x86_64-w64-mingw32-nm"
      OBJDUMP="x86_64-w64-mingw32-objdump"
      WINDRES="x86_64-w64-mingw32-windres"
      export CC CXX AR RANLIB LD STRIP OBJCOPY READELF NM OBJDUMP WINDRES

      # --- search paths: our prefix only, no sysroot ---
      # CPPFLAGS covers the autoconf probes ($CC -E without $CFLAGS).
      CPPFLAGS="-I$PREFIX/include"
      export CPPFLAGS
      CFLAGS="-O2"
      CFLAGS="$CFLAGS -I$PREFIX/include"
      CXXFLAGS="$CFLAGS"
      export CFLAGS CXXFLAGS
      # No -Wl,--undefined-version: that's ELF-only, ld for PE fails.
      LDFLAGS="-L$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
      export LDFLAGS
      # Look up .pc files in our prefix, ignore host ones.
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
      PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

      # --- build-system defaults: install into $OUT, find in $PREFIX ---
      AUTOCONF_CONFIGURE_FLAGS="--host=x86_64-w64-mingw32"
      AUTOCONF_CONFIGURE_FLAGS="$AUTOCONF_CONFIGURE_FLAGS --prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_TOOLCHAIN_FILE="$SYSDIR/x86_64-w64-mingw32-toolchain.cmake"
      CMAKE_PREFIX_PATH="$PREFIX"
      CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$CMAKE_TOOLCHAIN_FILE"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_INSTALL_PREFIX=$OUT"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_FLAGS
      MESON_CROSS_FILE="$SYSDIR/crossfile-x86_64-mingw.ini"
      MESON_FLAGS="--prefix=$OUT"
      MESON_FLAGS="$MESON_FLAGS --cross-file $MESON_CROSS_FILE"
      export MESON_CROSS_FILE MESON_FLAGS

      # --- rust: windows target, same linker family, cross pkg-config ---
      CARGO_BUILD_TARGET="x86_64-pc-windows-gnu"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC"
      CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR"
      RUSTFLAGS="-L $PREFIX/lib"
      PKG_CONFIG_ALLOW_CROSS="1"
      CC_x86_64_pc_windows_gnu="$CC"
      CFLAGS_x86_64_pc_windows_gnu="$CFLAGS"
      CXX_x86_64_pc_windows_gnu="$CXX"
      CXXFLAGS_x86_64_pc_windows_gnu="$CXXFLAGS"
      export CARGO_BUILD_TARGET CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER
      export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR RUSTFLAGS
      export PKG_CONFIG_ALLOW_CROSS
      export CC_x86_64_pc_windows_gnu CFLAGS_x86_64_pc_windows_gnu
      export CXX_x86_64_pc_windows_gnu CXXFLAGS_x86_64_pc_windows_gnu
  
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
      _bin="target/$CARGO_BUILD_TARGET/release/pngprobe"
      [ -f "$_bin" ] || _bin="$_bin.exe"
      if ! "$OBJDUMP" -p "$_bin" | grep -qi "libpng16"; then
        echo "error: pngprobe did not link libpng16 from \$PREFIX" >&2
        echo "--- objdump dump: ---" >&2
        "$OBJDUMP" -p "$_bin" >&2 || true
        exit 1
      fi
      mkdir -p "$OUT/bin"
      cp "$_bin" "$OUT/bin/"
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/x86_64-mingw"
  cp -rf "$OUT"/. "$NESTDIR/x86_64-mingw/"
  touch $NESTDIR/x86_64-mingw/.retrolunar-pngprobe
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
