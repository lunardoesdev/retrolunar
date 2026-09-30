# kmod build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 34, fetched **by git tag** (`v34`) — kernel.org carries no
  kmod release tarball, so `source.lua:7-9` uses the documented
  `git clone --depth=1 --branch "$tag" "$git" src` pattern with an
  `if [ ! -d src ]` guard.
- Build system: meson
- Installs: `libkmod.so`/`libkmod.a`, the kmod tools (`lsmod`, `insmod`,
  `rmmod`, `modprobe`, `modinfo`, `depmod`, …), `include/libkmod.h`,
  `modprobe.d` config. No `.pc` file.
- Requires: `kmod@source` only. `meson` is **not** required in the recipe —
  it is a *host* program the build shells out to, and it was added to the
  prefix at `topackage.md:44` precisely as kmod's prerequisite.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | Two Bionic gaps with no meson fallback check. `shared/util.c:383` calls `get_current_dir_name` and `libkmod/libkmod-index.c:224` calls `fread_unlocked`. I checked both against the sysroot: `llvm-nm --defined-only` on `libc.a` gives **zero** matches for `get_current_dir_name` (and no NDK header declares it) and **one** for `fread_unlocked` — but `stdio.h:347` marks it `__INTRODUCED_IN(28)`, so it is not available below API 28. Either way `get_current_dir_name` is fatal at every level. `topackage.md:44`. |
| aarch64-android24 | **WILL NOT BUILD** | Same. |
| aarch64-android35 | **WILL NOT BUILD** | Same — `fread_unlocked` becomes available at 35 but `get_current_dir_name` does not, so the package still fails. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | UNCERTAIN | kmod is a Linux kernel-module tool; `shared/util.c` and the module index code are Linux-specific and there is no Windows port. A mingw build is not plausibly viable. |
| clang-native | WILL BUILD | glibc provides both `get_current_dir_name` and `fread_unlocked`. kmod is a Linux tool and the host is Linux, so natively it is in its element. |

**API level notes.** `get_current_dir_name` has no `__INTRODUCED_IN` at all —
it is simply absent from Bionic, so **no API level fixes this.**
`fread_unlocked` is separately API-28-gated, which means even a kmod that did
not call `get_current_dir_name` would still fail on 21 and 24. Worth stating
precisely because it means the blocker is *doubly* fatal below 28.

**Risks / what a reviewer should check.**

1. **The recipe's own workarounds are all still there and all still
   correct** (`generic.lua:8-19`): completion directories emptied because the
   shell completions install to absolute paths `$OUT` does not own;
   `manpages=false` because `man/meson.build:1` does an unconditional
   `find_program('scdoc')` that is not in this prefix; and only the `xz`
   backend enabled because the prefix ships `liblzma.pc` but no `zlib.pc` and
   no `libzstd.pc`. Each is commented with its reason. This is the pattern
   AGENTS.md:25-29 asks for.
2. **`DESTDIR` was a live bug here and is now FIXED — do not reintroduce it.**
   The recipe previously read `DESTDIR="$OUT" meson install -C build`, which
   contradicts AGENTS.md:250-252: meson recipes must **not** add `DESTDIR`,
   because `$MESON_FLAGS` already carries `--prefix=$OUT`, so the two
   concatenate and the install lands in `$OUT$OUT`, outside
   `$NESTDIR/<sys>/`. The consequence was a **silent empty publish**, not an
   error — and it hit `clang-native` too, the one system that passes both
   symbol gates, so even the buildable case installed nothing. The line is now
   plain `meson install -C build` with the reason as a comment above it,
   mirroring `packages/fribidi/generic.lua:10-12`. `kmod` was the only recipe
   in the whole tree still passing `DESTDIR`; `fribidi` and `harfbuzz` were
   checked and use `ninja -C build install` with no `DESTDIR`, so they were
   already correct. **The check that catches a regression: `find "$OUT"
   -maxdepth 1 -name "$PREFIX"` must print nothing — a nested `$OUT$PREFIX`
   directory is the `DESTDIR` signature.**
3. **`meson compile -C build` was unserialised and is now `meson compile -C
   build --jobs 1`**, per AGENTS.md:226-229.
4. **kmod needs `liblzma` at link time** and the recipe enables the `xz`
   backend. That is consistent — but note there is no `require("xz")` in the
   recipe, so the build depends on `xz` being in the prefix without declaring
   it. If `xz` is ever removed from the tree, this recipe breaks at link time
   with no dependency edge to explain why. A `require("xz")` would be more
   honest, though meson finds it via pkg-config from the system path either
   way.
5. `topackage.md:44` is accurate: the version, the fetch-by-git reason and both
   glibc-isms are all correct as recorded. **Not stale.**

**How to verify once unblocked.**

- `lib/libkmod.so` (or `.a`) exists, plus `include/libkmod.h`.
- `lsmod`, `modinfo`, `depmod` exist in `bin/`.
- `pkg-config --exists libkmod` — expect **failure**: kmod ships no `.pc`, so
  verify the header and the library by path instead.
- `llvm-nm -u lib/libkmod.so | grep get_current_dir_name` — on a successful
  build this must be **empty**; a hit means the blocker is back.
- `modprobe.d/` exists with upstream's sample configs.
