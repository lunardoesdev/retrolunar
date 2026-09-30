REJECT

# openssl — stage 2 review

Verified against `AGENTS.md`, the three system files, and the real
`openssl-4.0.2` tarball (downloaded; `Configurations/15-android.conf` and
`Configure` read). Nothing was configured or built.

## The reported defect is CONFIRMED, and it is real

`packages/openssl/generic.lua:17-22`:

```sh
case "$HOST_ARCH" in
    aarch64) ssl_target=android-arm64 ;;
    armv7a)  ssl_target=android-arm ;;
    i686)    ssl_target=android-x86 ;;
    x86_64)  ssl_target=android-x86_64 ;;
esac
```

There is **no `*)` arm**. `HOST_ARCH` is `x86_64` on **both**
`x86_64-mingw` (`packages/x86_64-mingw/generic.lua:49`) and `clang-native`
(`packages/clang-native/generic.lua:47`), so both match the `x86_64)` arm.

On those two systems `$NDK`, `$TOOLBIN` and `$ANDROID_API` are all unset
(none is exported by either system file), so:

- `generic.lua:6` `export ANDROID_NDK_ROOT="$NDK"` sets it to the empty string;
- `generic.lua:13` `PATH="$TOOLBIN:$PATH"` prepends an empty element, i.e.
  **`.`** to `PATH`;
- `generic.lua:23` runs `./Configure android-x86_64 -D__ANDROID_API__=""`.

What OpenSSL then does is the decisive part, and it is *not* a clean failure.
In `Configurations/15-android.conf`, `android_ndk()` begins:

```perl
if ($now_printing =~ m|^android|) {
    return $android_ndk = { bn_ops => "BN_AUTO" };
}
```

Because the target string starts with `android`, the function **returns early
and never looks at `$ANDROID_NDK_ROOT` at all**. So configure does *not* die
with "`$ANDROID_NDK_ROOT is not defined`" — it proceeds, and the build runs
with `CC` from the environment (`x86_64-w64-mingw32-gcc` / `clang`) against
**glibc or Windows headers with no sysroot and no API level**. That is the
worst outcome: a silently wrong library rather than a loud error. The target
names themselves are fine — I confirmed `android-arm64`, `android-arm`,
`android-x86` and `android-x86_64` all exist in `15-android.conf`'s
`%targets`.

## Required changes

1. **`packages/openssl/generic.lua` — move the Android-only block into
   `packages/openssl/android.lua` and leave a `*)` arm behind.** Create
   `packages/openssl/android.lua`:

   ```lua
   -- Found for every Android target through the systems' recipe_fallbacks,
   -- so there is no per-target copy of this recipe.
   require("openssl@source")

   return recipe({
       build = [[
           cp -r $NESTDIR/source/openssl/* .
           export ANDROID_NDK_ROOT="$NDK"
           # Upstream's android-* target config probes for the NDK tools by
           # name in PATH (it tests `which clang`, then `which <triple>-gcc`)
           # and dies without a flag to change that; current NDKs ship
           # neither a bare clang in bin/ nor a triple-gcc wrapper. So this
           # one build puts $TOOLBIN in front of PATH. It is a recipe-local
           # exception: systems do not do this, and no other recipe may
           # rely on it.
           PATH="$TOOLBIN:$PATH"; export PATH
           # The target name and the API level come from the system, so this
           # recipe builds for any Android target rather than one hardcoded
           # android-arm64 at level 24.
           case "$HOST_ARCH" in
               aarch64) ssl_target=android-arm64 ;;
               armv7a)  ssl_target=android-arm ;;
               i686)    ssl_target=android-x86 ;;
               x86_64)  ssl_target=android-x86_64 ;;
               *) echo "openssl: unknown HOST_ARCH $HOST_ARCH" >&2; exit 1 ;;
           esac
           ./Configure "$ssl_target" -D__ANDROID_API__="$ANDROID_API" --prefix="$OUT" --libdir=lib no-shared no-tests no-docs no-engine no-dso no-dynamic-engine
           make -j1
           make install_sw
       ]]
   })
   ```

2. **Replace `packages/openssl/generic.lua` in full with the native/mingw
   shape** — the same configure line minus the NDK plumbing, guarded by a
   `*)` that refuses rather than guesses:

   ```lua
   require("openssl@source")

   return recipe({
       build = [[
           cp -r $NESTDIR/source/openssl/* .
           # No NDK here: $NDK/$TOOLBIN/$ANDROID_API are unset on this
           # system, and handing openssl an android-* target without them
           # makes 15-android.conf take its early-return branch and build
           # against host headers with no API level, silently.
           case "$HOST_OS" in
               linux|mingw32) ssl_target=linux-x86_64 ;;
               *) echo "openssl: unsupported HOST_OS $HOST_OS" >&2; exit 1 ;;
           esac
           ./Configure "$ssl_target" --prefix="$OUT" --libdir=lib no-shared no-tests no-docs no-engine no-dso no-dynamic-engine
           make -j1
           make install_sw
       ]]
   })
   ```

   Note the deliberate difference from change 1: `HOST_OS` rather than
   `HOST_ARCH`. Both `x86_64-mingw` and `clang-native` are `x86_64`, so the
   arch can never distinguish them; `HOST_OS` is `mingw32` vs `linux`
   (`packages/x86_64-mingw/generic.lua:50`,
   `packages/clang-native/generic.lua:48`) and can.

3. **`packages/openssl/source.lua:2` — the version pin is stale.** 4.0.2 is
   pinned; `releases/latest` is **`openssl-4.0.3`**, published 2026-09-29 and
   **not** a prerelease. Change `version = "4.0.2"` to `version = "4.0.3"`
   and the URL at `source.lua:6` to
   `https://github.com/openssl/openssl/releases/download/openssl-4.0.3/openssl-4.0.3.tar.gz`.
   Re-check `15-android.conf` against the 4.0.3 tarball after bumping; the
   target names used above are from 4.0.2 and should be re-verified, not
   assumed.

4. **`packages/openssl/stage1.md` — record the `15-android.conf` early-return
   trap**, because it is the opposite of what the recipe's own comment at
   `generic.lua:7-12` implies. Add to the "for a reviewer" section: "A missing
   `$NDK` does **not** produce a clear error. `android_ndk()` in
   `Configurations/15-android.conf` returns `{bn_ops => BN_AUTO}` early
   whenever the target name begins with `android`, before it ever reads
   `$ENV{ANDROID_NDK_ROOT}`. An `android-*` target configured without an NDK
   therefore builds against host headers with no API level rather than
   failing. This is why the `*)` arm in change 2 must `exit 1` rather than
   fall through."

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libcrypto.a`, `$PREFIX/lib/libssl.a` | `ls $PREFIX/lib/lib{crypto,ssl}.a` |
| `$PREFIX/include/openssl/ssl.h` | `test -f $PREFIX/include/openssl/ssl.h` |
| `$PREFIX/bin/openssl` | `test -x $PREFIX/bin/openssl` |
| no man pages, no modules | `no-shared no-docs no-engine no-dso no-dynamic-engine` at `generic.lua:23` mean no `.so`, no `engines/`, no `openssl.cnf` |
| **the build log must not contain a host sysroot or a missing-`-D__ANDROID_API__` warning** | grep the log for `android` — on Android every line should mention the NDK path |

Watch first: `make -j1` after `./Configure` on 4.0.2/4.0.3 — OpenSSL's
generated makefiles are parallel-hostile but serial is always safe, so this
should be uneventful. Second: the `no-tests` flag must actually keep
`providers/` tests out of `all`; if a test program links and fails, that is
the reason.