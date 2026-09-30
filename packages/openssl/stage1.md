# openssl build forecast

- Recipe: `generic.lua`, source `source.lua` — **and this recipe is
  Android-only in substance despite living in `generic.lua`.** See risk 1.
- Version pinned: 4.0.2 (GitHub release asset)
- Build system: OpenSSL's own `Configure` script (the perl configuration
  system). **Not autoconf, not cmake** — so `$AUTOCONF_CONFIGURE_FLAGS`,
  `$CMAKE_FLAGS` and the timestamp guard do not apply.
- Installs: `lib/libcrypto.a`, `lib/libssl.a`, the `include/openssl/` headers,
  `openssl.pc` and `libcrypto.pc`/`libssl.pc`. `make install_sw` means
  **software only** — no modules, no scripts, no documentation, no `openssl`
  CLI.
- Requires: `openssl@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The `case "$HOST_ARCH"` at `generic.lua:17-22` maps `aarch64` to `android-arm64` and passes `-D__ANDROID_API__="$ANDROID_API"`, both taken from the system (`aarch64-android24/generic.lua:37-38`, `:42`). The API level is therefore a *system* fact, which is exactly right — this recipe builds for any Android target rather than one hardcoded `android-arm64` at level 24, and the comment at `:14-16` says so. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; the `case` has an explicit `x86_64) ssl_target=android-x86_64` arm. |
| x86_64-mingw | WILL BUILD | The `case` at `:17-22` has **no `*)` arm**. On a non-Android system `$HOST_ARCH` is `x86_64`, which *does* match `x86_64)` and would set `ssl_target=android-x86_64` — a **wrong target**, not a missing one. Worse, `$NDK`, `$TOOLBIN` and `$ANDROID_API` are all unset on mingw, so `./Configure android-x86_64 -D__ANDROID_API__=""` would attempt an NDK cross build with no NDK. See risk 1. |
| clang-native | WILL BUILD | Same failure with a different manifestation: `$HOST_ARCH` is `x86_64`, so the same wrong `android-x86_64` target is selected. OpenSSL's own `Configure` would then look for an Android NDK that is not there. See risk 1. |

**API level notes.** The `-D__ANDROID_API__` value comes from the system's
`$ANDROID_API` (`aarch64-android24/generic.lua:37`), so the API level is a
system fact here in a way it is not for most packages — and that is correct
design, not a workaround. OpenSSL gates symbols on the API level, so a build at
21 and a build at 35 genuinely differ, and this recipe tracks that
automatically.

**Risks / what a reviewer should check.**

1. **This is the most important finding in the file: `generic.lua` is not
   system-neutral, and it silently produces a wrong build on two of the six
   systems rather than failing cleanly.** AGENTS.md:198-204 requires
   `generic.lua` to be system-neutral, with anything target-specific in a
   `packages/<name>/<sys>.lua` or `android.lua`. Here:
   - The `case` at `:17-22` only has `aarch64`/`armv7a`/`i686`/`x86_64` arms
     and **no `*)` default**, so it cannot fail loudly on an unknown arch.
   - `x86_64-mingw` and `clang-native` both report `HOST_ARCH=x86_64`, so both
     silently select `android-x86_64` and run an NDK cross-configure with
     `$NDK` unset.
   - `export ANDROID_NDK_ROOT="$NDK"` (`:6`) and
     `PATH="$TOOLBIN:$PATH"` (`:13`) are no-ops with an empty value, so
     nothing catches it.
   
   **The clean fix is to move this body to `packages/openssl/android.lua`**
   (every Android system reaches it through `recipe_fallbacks`) and give
   `generic.lua` a native/`mingw-windows` path, or at minimum add a `*)` arm
   that fails with a clear message. This is the same class of issue as the
   glog `WITH_UNWIND` false premise: a recipe that looks right and produces the
   wrong thing. **`topackage.md:63` records this as built** — but only for
   Android, and it does not mention the other four systems, so the gap has
   never been exercised.
2. **The `PATH="$TOOLBIN:$PATH"` at `:13` is a recipe-local exception and the
   comment says so explicitly** (`:8-12`): OpenSSL's `android-*` target config
   probes for the NDK tools *by name in PATH* (it tests `which clang`, then
   `which <triple>-gcc`) and dies without a way to change that; current NDKs
   ship neither a bare `clang` in `bin/` nor a triple-gcc wrapper. The comment
   also states that no other recipe may rely on it, and that systems do not do
   this. **That is exactly the right way to record such a thing** — an
   explicit, scoped, justified exception. Worth preserving verbatim.
3. **`install_sw` at `:27` is the right target for a target prefix**: software
   only, no modules, no scripts, no docs, no CLI. The `no-shared no-dso
   no-dynamic-engine no-engine no-tests no-docs` set is coherent and complete.
4. **libevent `require()`s openssl** (`libevent/generic.lua:1`), so this
   package is load-bearing, and the `-llog` finding from the glog/abseil round
   does **not** apply here — OpenSSL has no `__android_log_write` path. Worth
   recording as a negative result so a reviewer does not assume the gap applies
   tree-wide.
5. **`no-engine` means no hardware acceleration**, which on Android is
   correct — there is no `/dev/crypto` engine there.
6. `topackage.md:63` records: *"OpenSSL 4.0.2 (LFS 3.5.2; latest stable
   release)"*. Accurate as far as it went, and consistent with the Android-only
   reality. **Both the version and the Android-only shape are now stale**: the
   version is 4.0.3, and every system has a recipe.
7. **A missing `$NDK` does NOT produce a clear error — this is the opposite of
   what the old recipe comment implied, and it is why the `*)` arm must
   `exit 1`.** In `Configurations/15-android.conf`, `android_ndk()` returns
   `{bn_ops => "BN_AUTO"}` early whenever the target name begins with
   `android`, *before it ever reads* `$ENV{ANDROID_NDK_ROOT}`. Verified at
   `15-android.conf:22-24` in the 4.0.3 tarball:
   ```perl
   if ($now_printing =~ m|^android|) {
       return $android_ndk = { bn_ops => "BN_AUTO" };
   }
   ```
   So an `android-*` target configured with no NDK **builds against host
   headers with no sysroot and no API level rather than failing.** That is why
   the Android block moved to `android.lua` and why its `case` refuses an
   unknown arch rather than falling through.
8. **`generic.lua` now keys on `HOST_OS`, not `HOST_ARCH`.** `x86_64-mingw`
   and `clang-native` are both `x86_64`, so the arch can never distinguish
   them; `HOST_OS` is `mingw32` vs `linux` and can. The mingw arm selects
   openssl's **`mingw64`** target, not `linux-x86_64` — `mingw64` is a real
   target in `Configurations/10-main.conf:1727` with `sys_id => "MINGW64"` and
   `cflags => "-m64"`, and using the linux target on a PE toolchain would
   build a Linux library.
9. **Version bumped 4.0.2 -> 4.0.3** (`releases/latest`, published
   2026-09-29, not a prerelease). All four Android target names were
   re-verified in the **4.0.3** tarball rather than assumed from 4.0.2:
   `android-arm` (`15-android.conf:197`), `android-arm64` (`:230`),
   `android-x86` (`:260`), `android-x86_64` (`:268`).

**How to verify once built** (all systems now have a recipe; the Android rows
use `android.lua`).

- `lib/libcrypto.a` and `lib/libssl.a` exist; `include/openssl/ssl.h` exists.
- `pkg-config --modversion openssl` reports 4.0.3.
- `$OBJDUMP -f lib/libcrypto.a` prints `elf64-littleaarch64` on Android — this
  is also the check that catches a *host* build, which is the failure mode if
  the `Configure` target is ever wrong.
- `file lib/libcrypto.a`'s output should record the API level; compare against
  the system's `ANDROID_API` to confirm `-D__ANDROID_API__` was honoured.
- `llvm-nm --defined-only lib/libssl.a | grep -cw SSL_new` non-zero.
- `ls $OUT/bin/` must be **empty** — `install_sw` installs no CLI, and an
  `openssl` binary here would mean the wrong target was used.
- `ls $OUT/lib/engines-3/` should not exist (`no-engine`).
- `x86_64-mingw` must yield a **PE** library and `clang-native` an ELF one.
  `$OBJDUMP -f lib/libcrypto.a` showing `pei-x86-64` vs `elf64-x86-64` is what
  proves the `HOST_OS` case picked the right openssl target.
