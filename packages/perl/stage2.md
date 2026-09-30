REJECT

# perl — stage 2 review

## Required changes

1. **`packages/perl/generic.lua:48` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

2. **`packages/perl/generic.lua:8-9` — `export BUILD_ZLIB=False` /
   `export BUILD_BZIP2=0` are unexplained.** They suppress perl's own
   build-time zlib/bzip2 linkage, which is a real and probably correct choice
   for a cross build (perl's host-side module build would otherwise try to
   link target libraries into host executables). But `AGENTS.md:29` requires
   non-obvious recipe-local choices to be explained, and these two lines carry
   no comment. Add above line 8:

   ```sh
           # Skip perl's own build-time zlib/bzip2 linkage: the modules it
           # builds with the *host* toolchain must not link target libraries
           # out of $PREFIX.
   ```

3. **The `5.44` hardcoding is a tree-wide coupling that should be recorded.**
   `generic.lua:16-21` hardcodes `perl5/5.44/...` in six `-D` flags, and two
   other packages hardcode the same path to find the native perl's core
   modules:
   - `packages/intltool/generic.lua:10`
   - `packages/libxcrypt/generic.lua:8`

   When perl is bumped, all three must move together or they fail in
   confusing ways (intltool/libxcrypt fail at `configure`; perl itself
   installs into a path nothing looks in). Note this in `stage1.md`. The
   cleaner fix is to derive the version rather than hardcode it, but that is a
   refactor, not a defect in this recipe.

## What the forecast gets right

- `-Dcc="$CC"`, `-Dcppflags="$CPPFLAGS"`, `-Dldflags="$LDFLAGS"` correctly take
  the toolchain from the **system** rather than hardcoding one — that is the
  rule `AGENTS.md:211-222` is about, and this recipe follows it.
- `-Dusethreads` is right for this tree, and consistent with the libnl-3
  analysis: Bionic has no `libpthread` (verified: a link probe with the NDK
  clang fails with `ld.lld: error: unable to find library -lpthread`), but
  perl's threads support links against libc, where Bionic does provide the
  pthread symbols. **Note the contrast with libnl-3**: libnl-3's
  `AC_CHECK_LIB([pthread], …)` hard-*errors* on a missing libpthread and needs
  `--disable-pthreads`, whereas perl's Configure takes its own route. Do not
  copy libnl-3's fix here.
- `-Dprefix=$OUT` and the `-Dman*dir=$OUT/share/man/...` flags are right.
- `--with-build-python`-equivalent handling: perl's own `miniperl` is used for
  the build-time portion, which is correct for a cross build.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/perl` | `test -x $PREFIX/bin/perl` |
| `$PREFIX/lib/perl5/5.44/core_perl/` populated | `ls $PREFIX/lib/perl5/5.44/core_perl/CORE.so` — the arch module is what `intltool`/`libxcrypt` later look for |
| `$PREFIX/share/man/man1/perl.1` | `test -s $PREFIX/share/man/man1/perl.1` |
| threads support | `llvm-nm -D --undefined-only $PREFIX/bin/perl \| grep -c pthread_create` → non-zero |
| **the coupling check** | `test -f $PREFIX/lib/perl5/5.44/core_perl/CORE.so` must hold *before* building intltool or libxcrypt, or both fail at `configure` |
| target binary, never executed | `file $PREFIX/bin/perl` shows the target arch — do not run it |