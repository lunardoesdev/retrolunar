REJECT

# pkgconf — stage 2 review

## The reported question is settled: the recorded root cause is WRONG

The forecast left this open ("if it IS guarded, the recorded root cause is
wrong"). It is guarded. I checked the unpacked tree.

- `configure.ac:29` is `AC_CONFIG_HEADERS([libpkgconf/config.h])`, so the
  template is **`libpkgconf/config.h.in`**, not a top-level `config.h.in`.
  Verified: the only `config.h.in` in the tree is
  `nest/source/pkgconf/libpkgconf/config.h.in`.
- The `nl_langinfo` call site in pkgconf 3.0.7 sits **behind a
  `HAVE_NL_LANGINFO` configure guard**. pkgconf probes for the function at
  configure time and `#ifdef`s the call. That is why the recorded evidence at
  `topackage.md` says "compilation fails" and still cannot be explained by an
  unguarded call — the guard *is* present, so what fails is a **different**
  thing.

So the backlog entry's attribution to `nl_langinfo` is incorrect as stated.
`nl_langinfo` is `__INTRODUCED_IN(26)` at `langinfo.h:97` (verified, and I
compiled a probe: API 24 fails with "call to undeclared function",
API 26 and 35 compile) — so the API-26 observation is a true fact about the
symbol, but it is **not** what stops pkgconf, because pkgconf guards it.

The forecast's `aarch64-android35` row ("WILL BUILD (compile)") is the one to
believe. This is a category (iii) finding: **the backlog line's root cause is
wrong**, and it should be re-diagnosed rather than carried forward.

## Required changes

1. **`packages/pkgconf/stage1.md` — correct the root-cause attribution.** The
   `aarch64-android21` and `aarch64-android24` rows currently rest on
   "`nl_langinfo` … the call does not compile". Replace that reasoning with an
   admission that pkgconf 3.0.7 **does** guard the call behind
   `HAVE_NL_LANGINFO`, so `nl_langinfo` cannot be the blocker, and that the
   real cause is unrecorded. Mark the android21/24 rows **UNCERTAIN — cause
   not established**, not WILL NOT BUILD on a known cause. The API 26 fact
   about the symbol stays, but as context rather than as the mechanism.

2. **`packages/pkgconf/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

3. **`packages/pkgconf/generic.lua:8` — the timestamp guard touches a
   `config.h.in` that does not exist.** As above, the template is
   `libpkgconf/config.h.in`. Replace line 8 with:

   ```sh
           touch aclocal.m4 configure libpkgconf/config.h.in
   ```

   with a comment: `# libpkgconf/config.h.in: configure.ac:29 is
   AC_CONFIG_HEADERS([libpkgconf/config.h]).`

   As written, `touch config.h.in` creates a bogus empty file and leaves the
   real template older than the touched `aclocal.m4`, so make may re-run
   `autoheader` — which this prefix does not ship.

## What the forecast got right

- **Its own risk #1 is the most valuable thing here and it is correct:**
  pkgconf is a *host* tool in every build, and the `bin/pkgconf` this recipe
  installs into `$PREFIX/bin` is **not** what builds the tree. The systems set
  `PKG_CONFIG_LIBDIR` (`packages/aarch64-android24/generic.lua:82-88`) and a
  *host* binary reads it, because a target binary must never be executed
  here. Anyone who adds `require("pkgconf")` expecting it to supply the
  build-time pkg-config will be wrong.
- Its risk #4 correctly flags the bare `make`.
- The `clang-native` WILL BUILD verdict is right: glibc declares
  `nl_langinfo` unconditionally, so the guard resolves to "available".

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/pkgconf` | `test -x $PREFIX/bin/pkgconf` |
| `$PREFIX/share/man/man1/pkgconf.1` | `test -s $PREFIX/share/man/man1/pkgconf.1` |
| **the check that catches the guard bug** | the build log must contain no `autoheader` invocation |
| the real android21/24 blocker | on `aarch64-android24`, the *first* error in the log is the answer — do not assume it is `nl_langinfo` |