# file build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 5.46
- Build system: autotools
- Installs: `bin/file`; `share/misc/magic.mgc`; man page; **no library, no `.pc`**
- Requires: `file@source` only — **note: does NOT require a host `file` package**

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **UNCERTAIN** — not a flat WILL BUILD. Precondition: `$NATIVE_PREFIX/bin/file` must report `file-5.46`, which means `packages/file/clang-native.lua` has been built first. That row's premise correction still stands: cross-compiling means upstream never executes the target binary (`IS_CROSS_COMPILE`, configure.ac:237). If the precondition is unmet the failure is the exact-version check at `magic/Makefile.am:377-384` — **not** an execution problem and **not** a platform wall. |
| aarch64-android24 | **UNCERTAIN** — not a flat WILL BUILD. Precondition: `$NATIVE_PREFIX/bin/file` must report `file-5.46`, which means `packages/file/clang-native.lua` has been built first. Same as the API-21 row. |
| aarch64-android35 | **UNCERTAIN** — not a flat WILL BUILD. Precondition: `$NATIVE_PREFIX/bin/file` must report `file-5.46`, which means `packages/file/clang-native.lua` has been built first. Same as the API-21 row. |
| x86_64-android35 | **UNCERTAIN** — not a flat WILL BUILD. Precondition: `$NATIVE_PREFIX/bin/file` must report `file-5.46`, which means `packages/file/clang-native.lua` has been built first. Same as the API-21 row, arch-independent. |
| x86_64-mingw | **UNCERTAIN** — not a flat WILL BUILD. Precondition: `$NATIVE_PREFIX/bin/file` must report `file-5.46`, which means `packages/file/clang-native.lua` has been built first. Same as the API-21 row: cross-compiling, so upstream uses the PATH `file`, never the target binary. |
| clang-native | **UNCERTAIN** | On `clang-native` the built `file` *is* executable on the build host, so the `magic.mgc` generation would work — the only row where it can. Whether 5.46 completes cleanly otherwise is unverified. Note this is the one row where a host `file` 5.46 already present would be the natural answer, and the recipe does not require one. |

## API level notes

**Not an API-level blocker, and this is the point.** The wall is
**The real failure is a host-tool version mismatch, not execution.** With
cross-compiling set, `magic/Makefile.am:377-384` hard-fails unless the
`file` on PATH reports *exactly* `PACKAGE_VERSION` (5.46,
`configure:617`): it reads `--version`, strips the `file-` prefix, and
`exit 1`s on any mismatch. The build host here carries **file-5.48**,
so 5.48 != 5.46 and the build aborts. And there is **no configure switch**
to skip the database: `configure.ac` has nine `AC_ARG_ENABLE`/`AC_ARG_WITH`
— elf, elf-core, zlib, bzlib, xzlib, zstdlib, lzlib, lrziplib, libseccomp,
fsect-man5, warnings — none for magic, and `./configure --help` greps
zero hits for "magic". So `--disable-magic`, which I suggested below in
an earlier version of this file, **does not exist in file 5.46**.

The remedy is a **native `file` of the same version**, not a flag: build
`file@clang-native` first, so this same recipe produces
`$NATIVE_PREFIX/bin/file` at 5.46, which the loader puts first on `PATH`
(`src/loader.lua:412-415`), and the version check passes by construction.

**That cannot be automated from inside this recipe.** The obvious form,
`require("file@native")`, resolves to `clang-native` — whose recipe *is*
`packages/file/generic.lua` — so the require re-enters the file that issued
it and the loader recurses. I implemented it, measured the result
(`retrolunar install` → `C stack overflow` at the loader's module-loading
line, with and without a cross target) and removed it. `src/loader.lua` has
no module cache and no cycle guard — grepping for `cache`, `cycle` and
`loading[` finds nothing — and every other `@native` in the tree names a
*different* package (gperf for bison and libseccomp, tcl for expect, perl
for intltool, flex and bison for libnl-3), which is exactly why none of them
hit this. So the requirement is recorded as a **build order** in the recipe
rather than as a dependency: native first, then the targets. The builder
should treat a missing `$NATIVE_PREFIX/bin/file` as the first thing to
check.

## Risks / what a reviewer should check

- **There is no flag to reach for; a host `file` of the same version is
  the whole fix.** An earlier version of this file proposed
  `--disable-magic` as the obvious remedy and a `@native` route as a second
  option. **The first does not exist**: `configure.ac` has nine
  `AC_ARG_ENABLE`/`AC_ARG_WITH` (elf, elf-core, zlib, bzlib, xzlib, zstdlib,
  lzlib, lrziplib, libseccomp, fsect-man5, warnings), none for magic, and
  `./configure --help` greps zero hits. The second needed a real second
  recipe, which is now `packages/file/clang-native.lua`: the loader resolves
  `@native` to that file ahead of `generic.lua`
  (`src/loader.lua:186`), so the two are distinct and the dependency works.
  The native build must still be done **before** the target builds; the
  loader cannot express that ordering.
- **`require("file@native")` was implemented, measured, and reverted — do not
  retry it without reading this.** The literal symptom:
  `./builddir/retrolunar install --nest … --packages ./packages
  'file@aarch64-android24'` returns `rc=1` and
  `[string "-- retrolunar module loading...."]:104: C stack overflow`. It is
  a **crash, not a diagnosable error**: `src/loader.lua:104` is `pcall(fn)`,
  and `pcall` does not bound stack depth, so the re-entry exhausts the C
  stack. The duplicate-key guard at `src/loader.lua:166`
  (`error("recipe() duplicate entry for " .. key)`) is never reached, because
  execution dies inside the `require` before a second `recipe()` call — the
  stderr holds one "C stack overflow" and zero "duplicate entry". Reproduced
  with `file@clang-native` alone as well, so it is not target-specific. The
  root cause is that `src/loader.lua` has no module cache and no cycle guard
  (grep for `cache[`, `cycle`, `loading[` returns nothing; `key_stack` at
  `:84` exists only so `recipe()` enqueues under the right identity, at
  `:161`). **This is a real defect in the repo, not a quirk of this
  package**, and a cycle guard is worth having on its own merits — but it
  would not have fixed `file`; it would only have made the failure legible.
  What fixed it was a second, distinct recipe file.
- **This is the one place where a stage1 I wrote sent a reader looking for a
  wall that is not there.** I asserted the target binary was executed and
  built a whole WILL NOT BUILD verdict on it. Upstream already handles the
  cross case. Worth remembering that a plausible-sounding failure mode is
  worth exactly as much as a check, and this one cost a full review cycle.
- **The recipe is otherwise completely plain** — no flags, no platform
  file — which is consistent with a package that has not been worked on
  because it has not been solved.

## How to verify once built

- `bin/file` — `file bin/file` → `ELF 64-bit LSB pie executable, ARM aarch64,
  ... for Android NN` on a target, host x86_64 ELF on `clang-native`.
- `share/misc/magic.mgc` — the real artifact, and the thing whose absence
  would indicate a partial build.
- **The check that proves the host-tool fix worked:** `magic.mgc` exists
  *and* the build got past `magic/Makefile.am:377-384`. If the log shows
  "Cannot use the installed version of file (5.48) to cross-compile file
  5.46", then `$NATIVE_PREFIX/bin/file` was absent or not 5.46 — i.e.
  `file@clang-native` was not built first. That message is the single
  diagnostic that matters here.
- `test -x "$NATIVE_PREFIX/bin/file" && "$NATIVE_PREFIX/bin/file" --version`
  → `file-5.46`, run on the **host** before starting a target build. This is
  the precondition for every cross row.
- No library, no `.pc`.
