ACCEPT

# libxcrypt — stage 2 review

## The reported lead is adjudicated: it is a real defect, but the suggested fix is wrong

The adder reported a **lead, not a conclusion** and asked for adjudication. I
traced it through `configure.ac` and the answer is clear — and the adder's
proposed change would not fix it.

The mechanism, in execution order:

1. `configure.ac:355-391` — `--enable-obsolete-api=glibc` sets
   `enable_obsolete_api=1`, `enable_compat_suse=0`, `COMPAT_ABI=glibc`.
2. `configure.ac:444-455` — `--enable-hashes=strong,glibc` expands via
   `lib/hashes.conf`. `descrypt` carries flags `GLIBC,FREEBSD,NETBSD,OPENBSD,
   SOLARIS,OSX`, and `strong,glibc` selects it, so `hashes_enabled` ends in
   `,descrypt` and this block **does not fire**. The compat ABI survives.
3. **`configure.ac:473` — `if test x$enable_shared != xyes; then
   enable_obsolete_api=0; fi`.** This is the line that matters. The comment
   above it says it outright: *"The obsolete APIs are unconditionally
   excluded from the static library, so if we are not building the shared
   library, we are effectively not building obsolete APIs."*
4. `configure.ac:477-506` — because `enable_obsolete_api` is now 0,
   `compute-symver-floor` is never run, so `SYMVER_FLOOR=XCRYPT_2.0` and
   `SYMVER_MIN=XCRYPT_2.0` by the `:503-507` fallback.

**The recipe never passes `--enable-static`/`--disable-shared`, so
`enable_shared` is `yes` and step 3 does not fire on this build.** The
`--enable-obsolete-api=glibc` and `--enable-hashes=strong,glibc` flags are
therefore *not* obviously wrong, and removing them would change the ABI the
library ships without addressing the version-script mismatch the forecast
observed.

**Ruling on the adder's question:** dropping the two flags is **not** a
legitimate recipe change as a fix for this failure. It would trade a
glibc-compatible ABI (`crypt`/`crypt_r`/`xcrypt_gensalt*` under `XCRYPT_2.0`)
for no ABI at all, without demonstrated benefit — and the real diagnosis still
has to explain why the version script names symbols the archive does not
define. That question is answerable only from a build log, which I am not
permitted to produce.

**What the builder should do:** build it on `clang-native` first and read the
actual linker error. The three discriminating facts:

- if the log shows `ld.lld: error: version script assignment of 'XCRYPT_2.0' to
  symbol 'xcrypt_gensalt' failed` **while `enable_obsolete_api` was 1** in
  `config.log`, the cause is `INCLUDE_*` gating in
  `build-aux/scripts/gen-crypt-symbol-vers-h`, whose first `#if` is
  `defined PIC && ENABLE_OBSOLETE_API` — so a **static** build
  (`ENABLE_OBSOLETE_API` compiled out) drops the compat symbols from the
  version script while the `.ver` still lists them. The fix is then
  `--enable-shared` (or accepting a static library with no compat symbols),
  and the right place for it is `generic.lua` with a comment, since it is a
  package build choice, not a target fact;
- if `config.log` shows the `configure.ac:493` `XCRYPT_2.0)` branch firing,
  then the compat ABI *was* disabled by the symver floor and the flags are
  irrelevant — changing them changes nothing;
- if it links fine, the forecast's blocker was a stale observation from an
  older attempt.

Do **not** change the flags before the log exists.

## A real rule deviation, minor

`packages/libxcrypt/generic.lua:12` is a bare `make`, not `make -j1`
(`AGENTS.md:226-229`). Worth fixing, but it is a serialisation defect, not a
correctness one, and it does not affect the verdict above — the failure the
forecast describes happens at link time either way.

## What the forecast gets right

- It correctly identifies the failure as a **link-time version-script
  mismatch inside libxcrypt's own build**, present on glibc hosts too, rather
  than a Bionic gap. That is the right layer.
- It correctly refuses to present the flag interaction as a settled
  conclusion, and asks for adjudication rather than asserting a fix. That is
  exactly right, and it is why this is an ACCEPT.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libcrypt.so` (or `.a`) | `ls $PREFIX/lib/libcrypt.*` |
| `$PREFIX/include/crypt.h`, `xcrypt.h` | `test -f $PREFIX/include/crypt.h` — note `configure.ac` installs `xcrypt.h` only when a compat ABI is selected |
| the compat ABI question | `llvm-nm -D --defined-only $PREFIX/lib/libcrypt.so \| grep -c 'xcrypt_gensalt'` — 0 means no glibc-compatible ABI shipped |
| **the log check that settles it** | grep the build log for `enable_obsolete_api=` in `config.log`, and for `version script assignment` — those two lines decide everything above |

Build on `clang-native`: it is the fastest path to the version-script error,
and it is the system the forecast says fails identically to Android.