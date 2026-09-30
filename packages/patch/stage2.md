REJECT

# patch — stage 2 review

## Required changes

1. **`packages/patch/generic.lua:7` — the timestamp guard touches a
   `config.h.in` that does not exist.** In the unpacked tree, patch 2.8's
   `configure.ac` is `AC_CONFIG_HEADERS([config.h:config.hin])` — the
   *legacy* GNU style with a `.hin` extension, not `.h.in` — and the file on
   disk is `patch/config.hin`. There is no `config.h.in`. So line 7 creates a
   bogus empty `config.h.in` and leaves the real template stale relative to the
   touched `aclocal.m4`.

   Replace line 7 with:

   ```sh
           touch aclocal.m4 configure config.hin
   ```

   with a comment: `# config.hin, not config.h.in: patch 2.8 uses the legacy
   AC_CONFIG_HEADERS([config.h:config.hin]) form.`

   This is the third package in this shard using a `.hin` template (with
   `inetutils` and `libtool`, which has the hyphenated `config-h.in`). The
   AGENTS.md guard text at lines 230-234 says `config.h.in` unconditionally,
   which is exactly how these three get missed.

2. **`packages/patch/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## Note on the name-mismatch trap

The `patch` match in my scan against the forbidden-words list was a **false
positive**: it is the package's own name in `require("patch@source")` and in
the `cp -r $NESTDIR/source/patch/* .` line, not an application of `patch(1)`
to upstream sources. The recipe contains no `sed`, no patch application and
no `/dev/null`. The same false positive applies to `packages/meshoptimizer`
(`sed` appears only inside the comment text "MESHOPT_BUILD_GLTFPACK … passed
explicitly" — actually as the substring of `disabled`).

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/patch` | `test -x $PREFIX/bin/patch` |
| `$PREFIX/share/man/man1/patch.1` | `test -s $PREFIX/share/man/man1/patch.1` |
| static or shared per upstream default | `ls $PREFIX/bin/patch` is a target binary — check with `file`, and do not execute it |
| **the guard fix** | the build log must contain no `autoheader` invocation |