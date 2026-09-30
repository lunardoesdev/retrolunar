REJECT

# kmod — stage 2 review

## Required changes

1. **`packages/kmod/generic.lua:23` — `DESTDIR="$OUT" meson install` is a
   documented, build-breaking violation.** `AGENTS.md:249-252` says exactly
   this:

   > do **not** add `DESTDIR` to the install step — `$MESON_FLAGS` already
   > carries `--prefix=$OUT`, so `DESTDIR=$OUT ninja install` writes to
   > `$OUT$OUT`.

   Line 15 already passes `$MESON_FLAGS`, and
   `packages/aarch64-android24/generic.lua:136-137` sets
   `MESON_FLAGS="--prefix=$OUT"`. So the install lands in
   `$OUT$PREFIX/lib/...`, i.e. under a *nested* absolute path inside the
   staging dir, and `cp -rf "$OUT"/. "$NESTDIR/<sys>/"` publishes nothing
   where the consumer expects it. The result is a silent empty install, not
   an error.

   Replace line 23 with:

   ```sh
           meson install -C build
   ```

   and add the reason as a comment directly above it (mirroring
   `packages/fribidi/generic.lua:10-12`, which gets this right):

   ```sh
           # No DESTDIR: meson's --prefix is already $OUT (it comes from
           # $MESON_FLAGS), so DESTDIR would concatenate the two and the
           # install would land in $OUT$OUT.
   ```

2. **`packages/kmod/generic.lua:15-21` — `-Dzlib=disabled` is a target fact
   that belongs in the system file, or nowhere.** The comment at lines 13-14
   says the reason is that the NDK ships no `zlib.pc`/`libzstd.pc` "so meson's
   pkg-config lookup cannot" find them. That is an Android-sysroot property,
   not a kmod property, and the recipe is `generic.lua` — so on
   `clang-native`, where a real `zlib.pc` *is* available, kmod is being
   built without zlib for no reason. Either move it to
   `packages/kmod/android.lua` (the systems list `android` in
   `recipe_fallbacks`, so one file covers all Android targets), or drop it and
   accept zlib everywhere. Do not leave it in `generic.lua`.

   If you move it, `packages/kmod/android.lua` becomes:

   ```lua
   -- Found for every Android target through the systems' recipe_fallbacks,
   -- so there is no per-target copy of this recipe.
   require("kmod@source")

   return recipe({
       build = [[
           cp -r $NESTDIR/source/kmod/. .
           # The NDK sysroot ships no zlib.pc and no libzstd.pc, so meson's
           # pkg-config lookup cannot resolve either; -Dzlib=disabled keeps
           # meson from erroring on a dependency it cannot find.
           meson setup build $MESON_FLAGS \
               -Dbashcompletiondir= \
               -Dfishcompletiondir= \
               -Dmanpages=false \
               -Dzlib=disabled \
               -Dxz=enabled \
               -Dzstd=disabled
           meson compile -C build
           # No DESTDIR: meson's --prefix is already $OUT (it comes from
           # $MESON_FLAGS), so DESTDIR would concatenate the two and the
           # install would land in $OUT$OUT.
           meson install -C build
       ]]
   })
   ```

   and `generic.lua` keeps `-Dxz=enabled -Dzstd=disabled` without `-Dzlib`.

3. **`packages/kmod/generic.lua:22` — `meson compile -C build` is
   unserialised.** Per `AGENTS.md:226-229` the build must be single-job. Use
   `meson compile -C build --jobs 1` (or the equivalent `-j1` this tree uses
   for make). Note `packages/fribidi/generic.lua:14` has the same shape, so
   if the tree convention is being relaxed for meson, say so once — but as the
   rulebook currently stands, this is a deviation.

## What the forecast got right

- **The blocker claim is correct and I verified it independently.**
  `llvm-nm --defined-only` on
  `sysroot/usr/lib/aarch64-linux-android/libc.a` finds **zero** occurrences of
  `get_current_dir_name`, and finds
  `T fread_unlocked` — but `stdio.h:347` declares it
  `fread_unlocked(...) __INTRODUCED_IN(28)`. So the package is **doubly**
  fatal below API 28, exactly as reported: the first symbol is absent at every
  level, the second is present but gated at 28. This is the same class as
  `less` (API 26) and `ninja` (API 28) but strictly worse than both, because
  no target in this tree fixes it — `fread_unlocked` needs 28+ *and*
  `get_current_dir_name` needs a Bionic that never has it.

## What the forecast got wrong or did not say

- **The forecast must state that the `DESTDIR` bug means even
  `clang-native` — the one system that passes both symbol gates — installs
  nothing.** That is the actionable part and it is missing.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/*/libkmod.so` | `find $PREFIX -name 'libkmod*'` — after the DESTDIR fix this must be non-empty |
| `$PREFIX/include/libkmod.h` | `test -f $PREFIX/include/libkmod.h` |
| no man pages from kmod | `-Dmanpages=false`; kmod's own pages are the 10 named in `man/meson.build:3-14` (`man5`: `depmod.d`, `modprobe.d`, `modules.dep`; `man8`: `depmod`, `insmod`, `kmod`, `lsmod`, `modinfo`, `modprobe`, `rmmod`), so check **those** are absent: `! ls $PREFIX/share/man/man5/{depmod.d,modprobe.d,modules.dep}.5 $PREFIX/share/man/man8/{depmod,insmod,kmod,lsmod,modinfo,modprobe,rmmod}.8` must print nothing. **Do not** use `ls $PREFIX/share/man` — that directory is shared with `man-pages`, `systemd-man-pages` and `tcl` and is never empty, so the older form failed against any prefix built by more than one package |
| **the check that catches the bug itself** | `find "$OUT" -maxdepth 1 -name "$PREFIX"` must print nothing — a nested `$OUT$PREFIX` directory is the DESTDIR signature |

Build on `clang-native` first: it is the only system in the tree where both
symbol gates pass, so it is the one that can actually produce artifacts and
therefore the one that will expose required change 1.