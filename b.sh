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
  RECIPEDIR="$PACKAGEDIR/hello"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" export PACKAGEDIR NESTDIR RECIPEDIR OUT
          mkdir -p $OUT/hello
          cp -rf $RECIPEDIR/main.c $OUT/hello
      
  mkdir -p "$NESTDIR/source"
  cp -rf "$OUT"/. "$NESTDIR/source/"
  touch $NESTDIR/source/.retrolunar-hello
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
# --- hello@clang-native ---
if [ -f $NESTDIR/clang-native/.retrolunar-hello ] && [ $NESTDIR/clang-native/.retrolunar-hello -nt $PACKAGEDIR/hello/generic.lua ] && [ $NESTDIR/clang-native/.retrolunar-hello -nt $PACKAGEDIR/clang-native/generic.lua ]; then
  echo "skip hello@clang-native (fresh)"
else
  AR='llvm-ar' AS='$CC' AUTOCONF_CONFIGURE_FLAGS='--prefix=$PREFIX' CC='clang' CFLAGS='-O2 -fPIC' CMAKE_FLAGS='-DCMAKE_INSTALL_PREFIX=$PREFIX' CMAKE_PREFIX_PATH='$PREFIX' CPPFLAGS='-I$PREFIX/include' CXX='clang++' CXXFLAGS='-O2 -fPIC' LD='ld.lld' LDFLAGS='-L$PREFIX/lib  -Wl,-rpath-link,$PREFIX/lib -Wl,--undefined-version' OBJCOPY='llvm-objcopy' OBJDUMP='llvm-objdump' PKG_CONFIG_LIBDIR='$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig' PKG_CONFIG_PATH='' PREFIX='$NESTDIR/clang-native' RANLIB='llvm-ranlib' READELF='llvm-readelf' STRIP='llvm-strip' export AR AS AUTOCONF_CONFIGURE_FLAGS CC CFLAGS CMAKE_FLAGS CMAKE_PREFIX_PATH CPPFLAGS CXX CXXFLAGS LD LDFLAGS OBJCOPY OBJDUMP PKG_CONFIG_LIBDIR PKG_CONFIG_PATH PREFIX RANLIB READELF STRIP
  WORK=$(mktemp -d "$NESTDIR/tmp/work-XXXXXX")
  OUT=$(mktemp -d "$NESTDIR/tmp/out-XXXXXX")
  trap 'rm -rf "$WORK" "$OUT"' EXIT
  cd "$WORK"
  RECIPEDIR="$PACKAGEDIR/hello"
  PACKAGEDIR="$PACKAGEDIR" NESTDIR="$NESTDIR" RECIPEDIR="$RECIPEDIR" OUT="$OUT" export PACKAGEDIR NESTDIR RECIPEDIR OUT
          cp -rf $NESTDIR/source/hello/* .
          mkdir -p $OUT/bin
          $CC $CFLAGS main.c -o $OUT/bin/hello
      
  mkdir -p "$NESTDIR/clang-native"
  cp -rf "$OUT"/. "$NESTDIR/clang-native/"
  touch $NESTDIR/clang-native/.retrolunar-hello
  rm -rf "$WORK" "$OUT"
  trap - EXIT
fi
