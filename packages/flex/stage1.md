# flex build forecast

- Recipe: `generic.lua`, source `source.lua` (release asset)
- Version pinned: 2.6.4
- Build system: autotools (C++ for the scanner generator, C for the tables)
- Installs: `bin/flex`, `bin/lex`; `include/FlexLexer.h`; man page; **no `.pc`**
- Requires: `m4` (exists), `flex@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | topackage.md:25 records "blocked: cross build selects an incomplete realloc replacement". flex 2.6.4 has its own gnulib-style `src/alloc.c` with `#if defined(_MSC_VER) || defined(__MINGW32__)` and a POSIX path that relies on `realloc`. When configure cannot *run* its test program — which is exactly what happens when cross-compiling — the `ac_cv_func_realloc` answer falls to the cross-compile default, and flex 2.6.4's `configure.ac` then selects a fallback `realloc` that is incomplete. The result is a link or runtime failure in the built `flex`. |
| aarch64-android24 | **WILL NOT BUILD** | Same. Not API-level-dependent. |
| aarch64-android35 | **WILL NOT BUILD** | Same. Raising the API level does **not** help: the problem is configure's inability to *run* a probe, not a missing libc symbol. |
| x86_64-android35 | **WILL NOT BUILD** | Same, arch-independent. |
| x86_64-mingw | **UNCERTAIN** | The `_MSC_VER || __MINGW32__` branch in `src/alloc.c` takes the Windows path, so the realloc problem recorded for cross builds may not apply. But flex 2.6.4 on mingw still needs a runnable `m4` at build time (it regenerates `parse.c`/`scan.c` unless `--disable-bootstrap` is passed, which it is — `generic.lua:9`). I could not settle the outcome. |
| clang-native | **UNCERTAIN** | On `clang-native` configure *can* run its probes, so the realloc misdetection should not occur and the build plausibly completes. Unverified. |

## API level notes

**The recorded blocker is not an API-level one**, and this is worth
separating from the `nl_langinfo`/`mktime_z`/`stderr` family. flex's
problem is that autoconf *runs* a test program and cannot, under
cross-compiling. No new `aarch64-androidNN` directory fixes that; the
platform is what it is. The realistic fixes are upstream (a
cross-compile-safe `AC_RUN_IFELSE` with a sane default) or a configure
cache answer, and flex 2.6.4 exposes no `ac_cv_func_realloc`-shaped
variable the systems file could set — I did not verify that last point
directly, and it is the first thing to check.

## Risks / what a reviewer should check

- **`--disable-bootstrap` at `generic.lua:9` is correct and important.**
  Without it flex would try to run a *previously built* `flex` to
  regenerate its own scanner, which on a cross build means executing a
  target binary. The release ships the generated `scan.c`, so skipping the
  bootstrap is both correct and necessary.
- **`--disable-static` was removed.** The recipe used to build a *shared*
  `libfl.so` in an otherwise static prefix, with no rpath to load it. It now
  passes `--enable-static --disable-shared --with-pic`, matching every other
  package here. An earlier version of this file called the flag a "latent
  mistake" but left it in place; that was the wrong call, since it is a flag
  and not a patch.
- **flex is a dependency of `packages/libnl-3` via `flex@native`.** So this
  blocker does **not** propagate: `libnl-3` needs a *host* flex, built for
  `clang-native`, where the row above is UNCERTAIN rather than blocked. If
  `flex@clang-native` also turns out to fail, `libnl-3` loses its grammar
  generator and would need a different answer. That chain is the most
  important consequence of this file and it is not recorded anywhere else.
- **`m4` is a real dependency** and is in the prefix. flex's generated
  `parse.y` handling invokes m4 at *install/configure* time only if the
  bootstrap runs, which it does not.

## How to verify once built

Not verifiable on any cross target today. On `clang-native`:

- `bin/flex`, `bin/lex`
- `include/FlexLexer.h`
- `file bin/flex` → host x86_64 ELF on clang-native, Android ELF if a
  cross build ever works
- `lib/` — check whether a `libfl.so` appeared; its presence would confirm
  `--disable-static` is in effect and would be worth questioning
