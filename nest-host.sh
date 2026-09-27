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
      CC="clang"
      export CC
      CXX="clang++"
      export CXX
      AR="llvm-ar"
      export AR
      RANLIB="llvm-ranlib"
      export RANLIB
      LD="ld.lld"
      export LD
      AS="$CC"
      export AS
      STRIP="llvm-strip"
      export STRIP
      OBJCOPY="llvm-objcopy"
      export OBJCOPY
      READELF="llvm-readelf"
      export READELF
      OBJDUMP="llvm-objdump"
      export OBJDUMP
      CPPFLAGS="-I$PREFIX/include"
      export CPPFLAGS
      CFLAGS="-O2 -fPIC"
      export CFLAGS
      CXXFLAGS="-O2 -fPIC"
      export CXXFLAGS
      LDFLAGS="-L$PREFIX/lib  -Wl,-rpath-link,$PREFIX/lib -Wl,--undefined-version"
      export LDFLAGS
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
      export PKG_CONFIG_LIBDIR
      PKG_CONFIG_PATH=""
      export PKG_CONFIG_PATH
      AUTOCONF_CONFIGURE_FLAGS="--prefix=$OUT"
      export AUTOCONF_CONFIGURE_FLAGS
      CMAKE_PREFIX_PATH="$PREFIX"
      export CMAKE_PREFIX_PATH
      CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX"
      export CMAKE_FLAGS
  
      cp -rf $NESTDIR/source/hello/* .
      mkdir -p $OUT/bin
      $CC $CFLAGS main.c -o $OUT/bin/hello
  
  mkdir -p "$NESTDIR/clang-native"
  cp -rf "$OUT"/. "$NESTDIR/clang-native/"
  touch $NESTDIR/clang-native/.retrolunar-hello
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
