ACCEPT

# oniguruma — stage 2 review

Reviewed against `AGENTS.md`, `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`, and
the real 6.9.10 tarball (downloaded, listed, files read — nothing built).

## What the recipe gets right

- **Config template name is the real one.** `generic.lua:10` touches
  `src/config.h.in`, which is what `configure.ac:7` (`AC_CONFIG_HEADERS([src/config.h])`)
  implies. I listed the extracted tree: there is no top-level `config.h.in`,
  so the standard guard line would have failed here. The adder read the tree.
- **Guard position is right**: after `./configure`, before `make`.
- **Guard also covers `Makefile.in`.** `find . -name 'Makefile.in' | xargs touch`
  matters here because the tree is recursive — `src/`, `test/`, `sample/` each
  ship one (verified: 4 `Makefile.in` files).
- **No `config.status` / `libtool` shipped**, verified by listing the archive, so
  their absence from the touch list is correct, not an oversight. Same for
  libseccomp, libunwind and libnl-3.
- **`make -j1` everywhere**, no `sed`, no patch, no `/dev/null`, no `-j$(nproc)`.
- **Flags come from the system.** `--enable-static --disable-shared --with-pic`
  is a package-local build choice (static-with-PIC is this prefix's convention),
  and the recipe says why in a comment. `--host`, `--build` and `--prefix` are
  all inherited from `$AUTOCONF_CONFIGURE_FLAGS`. Nothing is `export`ed, no
  target fact is hardcoded.
- **No host programs.** `SUBDIRS = src test sample` (`Makefile.am:5`); `test/`
  and `sample/` declare only `check_PROGRAMS` (`test/Makefile.am:14`,
  `sample/Makefile.am:16`), which `make all` does not build. `mktable`
  (`src/Makefile.am:83`) is a bare target, not in any `_PROGRAMS`.
  `install-data-am:` is empty in both `test/Makefile.in:1087` and
  `sample/Makefile.in:1236`, so `make install` walking into them is a no-op —
  stage1 item 4 is accurate.
- **Source recipe is correct.** Version 6.9.10 is the current release (checked
  `releases/latest`: tag `v6.9.10`). URL returns 200. Top dir is
  `onig-6.9.10/`, stripped. `dl/` guard + `curl -C -` resumable. Lands in
  `$OUT/oniguruma/`.
- **`require("oniguruma@source")`** is the right spelling.
- **stage1.md is honest.** It opens by saying nothing was built, and its
  riskiest claim — that `AC_FUNC_ALLOCA` is link-only in the generated
  `configure` — I checked in the shipped script (lines ~14099-14180): both
  probes use `ac_fn_c_try_link`, never `ac_fn_c_try_run`. The only two
  `ac_fn_c_try_run` calls in the whole file are at 1971 and 14229, in other
  macros. Cross-safe, as claimed.
  The `x86_64-mingw` row's "moderate confidence" **has** a stated reason
  (a negative grep, not a positive finding) — that is the honest way to mark it.

## Corrections to stage1.md (do not change the build)

1. `stage1.md:24` — "No man pages: nothing in the tree is in `*_MANS`" is
   right, but `bin_SCRIPTS = onig-config` (`Makefile.am:20`) means the install
   is **not** header+lib only. Expect `bin/onig-config`.
2. `stage1.md:21` — `onigposix.h` really is absent: `configure.ac:17` defaults
   `enable_posix_api=no`. Confirmed. No change.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libonig.a` | `llvm-nm --defined-only $PREFIX/lib/libonig.a` shows `T onig_init` |
| `$PREFIX/include/oniguruma.h`, `$PREFIX/include/oniggnu.h` | `test -f` both (`src/Makefile.am:7`, `include_HEADERS`) |
| `$PREFIX/lib/pkgconfig/oniguruma.pc` | `pkg-config --modversion oniguruma` → `6.9.10` |
| `$PREFIX/bin/onig-config` | `test -x`; it is a generated shell script |
| no man pages, no `bin/` programs other than the above | `ls $PREFIX/share/man` absent |

Also expect a rerun of `sh build.sh` to print `skip oniguruma (fresh)`.

## Where the builder is most likely to be wrong

Look here first, in this order:

1. **The `x86_64-mingw` row.** stage1 rates it moderate confidence for an
   honest reason (negative grep), and it is the row most likely to fail. If you
   build mingw, the thing to check is `AC_CHECK_HEADERS(sys/time.h unistd.h
   sys/times.h)` — all three exist in mingw-w64 — so configure will get past
   headers and the failure, if any, will be in `src/` C, not configure.
   `configure.ac:84-91` only adds `libonig.def` and `-no-undefined` when
   `enable_shared=yes`; with `--disable-shared` that branch does not fire, so
   a mingw failure is a source-level POSIX issue, not a linker one.
2. **`make install` walking into `test/` and `sample/`.** Harmless but it is
   three extra `make` invocations; do not read it as a failure.
3. **`onig-config` generation.** `Makefile.am:22` declares `onig-config:
   onig-config.in` with **no recipe**, and the script is actually produced by
   `config.status` (`AC_CONFIG_FILES([... onig-config])` plus
   `AC_CONFIG_COMMANDS([default],[chmod +x onig-config],[])`,
   `configure.ac:77-79`). If `bin/onig-config` is missing or not executable,
   the cause is the `chmod` `config.status` command, not the recipe.
4. **Static + PIC.** `--with-pic` is a genuine libtool option here — I
   confirmed the `pic_mode` handling at `configure:8949-8957` (it is libtool's
   own, not an unrecognised option that would only warn).