#!/bin/sh
set -eu
NESTDIR='/home/si/ond/git/retrolunar/nest'
PACKAGEDIR='/home/si/ond/git/retrolunar/packages'
mkdir -p "$NESTDIR/tmp"
# --- hello@source ---
if [ -f $NESTDIR/source/.retrolunar-hello ] && [ $NESTDIR/source/.retrolunar-hello -nt $PACKAGEDIR/hello/source.lua ]; then
  echo "skip hello@source (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/source"
  RECIPEDIR="$PACKAGEDIR/hello"
  SYSDIR="$PACKAGEDIR/source"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      mkdir -p $OUT/hello
      cp -rf $RECIPEDIR/main.c $OUT/hello
  
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
  touch $NESTDIR/source/.retrolunar-hello
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- hello@clang-native ---
if [ -f $NESTDIR/clang-native/.retrolunar-hello ] && [ $NESTDIR/clang-native/.retrolunar-hello -nt $PACKAGEDIR/hello/generic.lua ] && [ $NESTDIR/clang-native/.retrolunar-hello -nt $PACKAGEDIR/clang-native/generic.lua ] && [ $NESTDIR/clang-native/.retrolunar-hello -nt $PACKAGEDIR/clang-native ]; then
  echo "skip hello@clang-native (fresh)"
else
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  PREFIX="$NESTDIR/clang-native"
  RECIPEDIR="$PACKAGEDIR/hello"
  SYSDIR="$PACKAGEDIR/clang-native"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" PREFIX="$PREFIX" SYSDIR="$SYSDIR" export PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR
      # --- toolchain: local clang + llvm binutils ---
      CC="clang"
      CXX="clang++"
      AR="llvm-ar"
      RANLIB="llvm-ranlib"
      LD="ld.lld"
      AS="$CC"
      STRIP="llvm-strip"
      OBJCOPY="llvm-objcopy"
      READELF="llvm-readelf"
      OBJDUMP="llvm-objdump"
      export CC CXX AR RANLIB LD AS STRIP OBJCOPY READELF OBJDUMP

      # --- search paths: headers, libraries, pkg-config ---
      # $PREFIX points at this system's nest dir, where deps landed.
      CPPFLAGS="-I$PREFIX/include"
      CFLAGS="-O2 -fPIC"
      CXXFLAGS="-O2 -fPIC"
      LDFLAGS="-L$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
      LDFLAGS="$LDFLAGS -Wl,--undefined-version"
      export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
      # Ignore host .pc files: only ours count.
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
      PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$PREFIX/share/pkgconfig"
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

      # --- build-system defaults: install into $OUT ---
      AUTOCONF_CONFIGURE_FLAGS="--prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_PREFIX_PATH="$PREFIX"
      CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$OUT"
      CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_PREFIX_PATH CMAKE_FLAGS
  
      cp -rf $NESTDIR/source/hello/* .
      mkdir -p $OUT/bin
      $CC $CFLAGS main.c -o $OUT/bin/hello
  
  for _pc in "$OUT"/lib/pkgconfig/*.pc "$OUT"/share/pkgconfig/*.pc; do
    [ -f "$_pc" ] || continue
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        *"$OUT"*) printf "%s\n" "$_line" | awk -v o="$OUT" -v p="$PREFIX" '{ gsub(o, p); print }';;
        *) printf "%s\n" "$_line";;
      esac
    done < "$_pc" > "$_pc.fixed" && mv "$_pc.fixed" "$_pc"
  done
  mkdir -p "$NESTDIR/clang-native"
  cp -rf "$OUT"/. "$NESTDIR/clang-native/"
  touch $NESTDIR/clang-native/.retrolunar-hello
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
