REJECT

# curl 8.22.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`curl-8.22.0` tarball. I did not build.

**Adder B's finding #3: the `--without-ssl` IS deliberate and documented, so it
is not a silent feature loss — but the reason given for it is wrong, and it
sits in the wrong file. And there is a second, harder defect the forecast did
not find at all.** curl has no line in `topackage.md` (it is not an LFS
package), so the recipe has never been recorded as built and both defects are
live.

## Required changes

### 1. `packages/curl/generic.lua:11` — the timestamp guard names a file that does not exist

```
        touch aclocal.m4 configure config.h.in
```

curl's config template is not `config.h.in`:

```
configure.ac:40:AC_CONFIG_HEADERS(lib/curl_config.h)
$ ls config.h.in
ls: cannot access 'config.h.in': No such file or directory
$ ls lib/curl_config.h.in
lib/curl_config.h.in
```

So `touch ... config.h.in` creates a stray empty `config.h.in` in `$WORK` and
leaves the real template un-refreshed — the guard does not do the job it is
there for. This is the same trap as e2fsprogs, and the tree already has the
precedent for non-standard names (`libnl-3`, `libunwind` → `include/config.h.in`;
`oniguruma` → `src/config.h.in`; `libseccomp` → `configure.h.in`).

**Replace line 11 with:**

```
        touch aclocal.m4 configure lib/curl_config.h.in
```

### 2. `packages/curl/generic.lua:7-9` — the `--without-ssl` reason is wrong, and it belongs in `android.lua`

The current comment:

```
        # OpenSSL static archives reference stderr, which API 21 only
        # provides as a macro (real symbol needs 23+); curl's configure
        # probes fail to link. Stick to no-ssl until the floor moves.
```

Two problems, in order of importance:

**(a) The file is wrong.** `--without-ssl` is in `generic.lua`, so it applies
to `clang-native` and `x86_64-mingw` too — systems where the stated reason does
not exist at all (glibc and mingw-w64 both have a real `stderr`). AGENTS.md is
explicit: *"Keep `generic.lua` system-neutral. Any flag, cache answer, or
workaround that is only correct for one target belongs in
`packages/<name>/<sys>.lua`."* An API-23 floor is the clearest possible
one-target fact. The correct home is `packages/curl/android.lua`, which one
file covers for all 56 Android systems through `recipe_fallbacks` — exactly the
pattern `bash/android.lua` and `binutils/android.lua` already use in this
shard.

**(b) The reason is not the blocker, and the recipe never takes the dependency
anyway.** The comment reasons about "OpenSSL static archives", but
`generic.lua` does not `require("openssl")` — with `--without-ssl`, OpenSSL is
not in the dependency graph at all. The honest statement is that this recipe
deliberately does not link a TLS backend. And there is a second, independent
reason the API-21 story is not the whole truth: the tree's own OpenSSL is built
for this prefix, and even on `aarch64-android35` the recipe would still drop
TLS, because the flag is unconditional. The feature is gone at *every* API
level, not "until the floor moves".

**Required:** delete lines 7-9 from `generic.lua` and create
`packages/curl/android.lua`:

```lua
require("zlib")
require("curl@source")

-- Found for every Android target through the systems' recipe_fallbacks, so
-- there is no per-target copy of this recipe.
return recipe({
    build = [[
        cp -r $NESTDIR/source/curl/* .
        # No TLS backend on Android. This recipe does not require openssl at
        # all, so the flag is a deliberate capability reduction rather than a
        # build workaround: libcurl here speaks http and ftp only. The reason
        # it cannot simply be switched on is that the prefix's OpenSSL static
        # archives reference stderr, which Bionic only provides as a macro
        # below API 23, so a static link fails on the older Android systems;
        # and the flag lives here rather than in generic.lua because that
        # wall is an Android fact, not a target-independent one.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-shared --enable-static --without-ssl --with-zlib="$PREFIX" --without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3 --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-docs
        touch aclocal.m4 configure lib/curl_config.h.in
        find . -name 'Makefile.in' | xargs touch
        make -j1 -C lib
        make -C lib install
        make -C include install
        make install-pkgconfigDATA
    ]]
})
```

and change `generic.lua` to the same body **without** `--without-ssl` and
without the SSL paragraph. On `clang-native` and `x86_64-mingw` that gives a
curl with TLS, which is what those systems can support.

If the adder prefers not to add a platform file, the fallback is to keep
`--without-ssl` in `generic.lua` but say plainly in the comment that the
resulting `libcurl.a` has no HTTPS support **on any system**, so nobody reads
it as a temporary Android-only workaround.

### 3. `packages/curl/stage1.md:6` — `bin/curl` and `lib/metalink/` are not installed

The "Installs" line claims `bin/curl`, `bin/curl-config` and
`lib/metalink/` helpers. The recipe installs only three targets
(`generic.lua:13-15`): `make -C lib install`, `make -C include install`,
`make install-pkgconfigDATA`. `bin/` is never installed, and `lib/metalink/` is
built by `--with-libmetalink` (off) or as part of `make` in `lib/metalink/`,
which is not in `-C lib`'s install set. `stage1.md` suspects this itself at
lines 42-49 and is right. Delete all three from the "Installs" line and from
"How to verify".

The narrow install is correct and deliberate — it is how you get a library
without the CLI — so it needs a comment in the recipe saying so. Add to
`generic.lua` above the `make` line:

```
        # Install only the library, the public headers and the .pc. The
        # top-level 'make install' would also install bin/curl, the curl
        # config script and the docs, none of which belong in a target
        # prefix.
```

### 4. Nothing else is required

`--without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3
--without-libssh2` and the protocol list are all real curl `--without-*`
options and all host-side feature reductions. `make -j1 -C lib` is serial. The
un-flagged `make -C lib install` / `make -C include install` lines are install
targets, not compiles, so they are not a serial-build violation.

## One latent problem worth recording

`--with-zlib="$PREFIX"` puts `-L$PREFIX/lib -lz` on the link line. On
`x86_64-mingw` this prefix's zlib installs as **`libzlib.a`**, not `libz.a`:
zlib's `CMakeLists.txt:170-172` only applies `OUTPUT_NAME z` inside
`if(UNIX)`, and `CMAKE_SYSTEM_NAME Windows` leaves `UNIX` false. This is the
name-mismatch trap AGENTS.md documents, and `packages/libpng` already works
around it by symlinking `libz.* → libzlib.*` in `$PREFIX` first; curl does not.

I checked whether it fails configure: it will not, because mingw-w64's
toolchain search falls through to whatever `-lz` resolves to, and if nothing on
this host provides it, curl's zlib probe simply reports no zlib and carries on
with `--without-zlib` behaviour. So the failure mode is a silent feature loss,
not a configure error. If a mingw build ever shows "curl: no zlib support", the
fix is the same `libz.*` symlink `libpng` uses, added to curl's recipe with a
comment — not a flag change.

## Carried to the build

- `lib/libcurl.a` — `llvm-objdump -f lib/libcurl.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/curl/curl.h` — `[ -f include/curl/curl.h ]`.
- `lib/pkgconfig/libcurl.pc` — `pkg-config --modversion libcurl` → `8.22.0`.
- No TLS: `llvm-nm lib/libcurl.a | grep -ci ssl` → **0**. This is the check that proves the `--without-ssl` decision took effect; on `clang-native` and `x86_64-mingw` after change 2 it should be **non-zero**, and if it is zero there, the platform file is not being picked up.
- `bin/` must be **absent**; `lib/metalink/` must be **absent**.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed — the recipe rework is complete and correct

This is the fix this shard got right. All three required changes landed, and
  each one checks out against the tree and against the loader's own rules.

- **Required change 1, both files.**

      $ grep -m1 AC_CONFIG_HEADERS nest/source/curl/configure.ac
      AC_CONFIG_HEADERS(lib/curl_config.h)

      $ find nest/source/curl -name 'curl_config*'
      nest/source/curl/lib/curl_config-cmake.h.in
      nest/source/curl/lib/curl_config.h.in

  `generic.lua:13` and `android.lua:19` both read
  `touch aclocal.m4 configure lib/curl_config.h.in`. That is the autotools
  template; `curl_config-cmake.h.in` is the cmake one and correctly not named.
  Guard position is right in both files — `./configure` on line 12 / line 18,
  guard immediately after, `make -j1 -C lib` on line 15 / line 21.
  `find . -name 'Makefile.in' | xargs touch` is necessary and sufficient here:
  curl ships 22 of them across `lib/`, `include/`, `include/curl/`, `src/`,
  `scripts/`, `docs/`, `projects/`, `tests/` and its subdirectories, so a
  single top-level touch would have missed all but one.

- **Required change 2, and it is complete in the way that matters.** The flag
  really has moved:

      $ grep -c -- '--without-ssl' packages/curl/generic.lua
      0
      $ grep -c -- '--without-ssl' packages/curl/android.lua
      1

  `generic.lua:7-11` now explains why TLS is left to the system's own detection
  there, and `android.lua:9-17` carries the Android-only reason. Apart from that
  one flag and that comment, the two configure lines are identical
  (`--disable-shared --enable-static [--without-ssl] --with-zlib="$PREFIX"
  --without-libpsl --without-libidn2 --without-nghttp2 --without-nghttp3
  --without-libssh2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict
  --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp
  --disable-gopher --disable-mqtt --disable-docs`), and so are the three
  install steps and the guard. Nothing was dropped in the split.

- **The spelling of the fallback is right.** I checked that one
  `android.lua` really does cover every Android target, because a per-target
  copy would have been the easy mistake:

      $ for d in packages/*android*/; do grep -L 'recipe_fallbacks' $d/generic.lua; done
      (no output)

  All 56 `*-androidNN` systems declare `recipe_fallbacks = {"android"}`. Only
  `x86_64-mingw` and `clang-native` declare none, and those two are exactly the
  systems that must get TLS — so they fall through to `generic.lua`. The split
  is correct at every one of the 58 systems.

- **The `android.lua` comment's factual claim holds.** "Bionic provides
  `stderr` as a macro below API 23 (a real symbol needs 23+)" is right; NDK r28b
  `usr/include/stdio.h:62-77` is
  `#if __ANDROID_API__ >= 23` / `extern FILE* _Nonnull stderr __INTRODUCED_IN(23)`
  versus `#else` / `extern FILE __sF[] __REMOVED_IN(23, …)` /
  `#define stderr (&__sF[2])`. And "this recipe does not require openssl at all"
  is true of both files — neither calls `require("openssl")`, even though
  `packages/openssl` exists in this prefix, which is the honest framing this
  stage2 asked for.

- **Required change 3's recipe half is done**: the narrow-install comment is
  present above the `make` line in both `generic.lua:16-18` and
  `android.lua:22-24`, and `stage1.md:6` no longer claims `bin/curl`,
  `curl-config` or `lib/metalink/`. I confirmed the three install targets are
  real: `Makefile.in:604` defines `install-pkgconfigDATA`, `Makefile.am:101-102`
  is `pkgconfigdir = $(libdir)/pkgconfig` / `pkgconfig_DATA = libcurl.pc`, and
  `include/Makefile.am` recurses into `include/curl`, so `make -C include
  install` installs the public headers.

- Hygiene: no `export` of search flags, no `sed`, no `/dev/null`, no patch, no
  `-j` above 1 anywhere; the un-flagged `make -C lib install` /
  `make -C include install` lines are install targets, not compiles.

### Still wrong

The recipe is now right, and the forecast still describes the recipe this
  rework replaced. `stage1.md` contradicts `generic.lua` on nearly every line,
  including on the one thing the rework was about:

- **`packages/curl/stage1.md:11`** — quotes the deleted comment verbatim
  ("OpenSSL static archives reference stderr, which API 21 only provides as a
  macro (real symbol needs 23+); curl's configure probes fail to link. Stick to
  no-ssl until the floor moves"), attributes it to `generic.lua:7-8`, and then
  says "The recipe therefore passes `--without-ssl` (`generic.lua:9`)".
  `generic.lua` has no such comment and no such flag. Line 9 is now a comment
  line inside the TLS paragraph.

- **`packages/curl/stage1.md:12`, `:13`, `:14`** — all reason about
  `--without-ssl` "still applying" across the Android family and about what
  would change "if the floor ever moved". That framing is gone; the flag is now
  a permanent, documented capability reduction on Android.

- **`packages/curl/stage1.md:15`** — "`generic.lua:9` passes `--without-ssl`
  unconditionally, so mingw also gets a curl with no TLS". This is now exactly
  backwards: mingw gets `generic.lua` and therefore **does** get TLS, which is
  the entire point of the split. This is the single most misleading line in the
  shard, because it states the opposite of the rework's intent as fact.

- **`packages/curl/stage1.md:42-49`** — "The recipe comment does not say so, and
  the 'Installs' line in this file claims `bin/curl` is installed — **that claim
  is probably wrong.**" Both halves are now resolved: `stage1.md:6` was
  corrected, and the recipe carries the narrow-install comment at
  `generic.lua:16-18`. The whole risk bullet should be deleted, not amended.

- **`packages/curl/stage1.md:63-64`** — "`readelf -s lib/libcurl.a | grep -i ssl`
  → **empty**, which is the check that the `--without-ssl` decision actually took
  effect". Only true on Android now. As written it tells the builder that an
  empty result is the pass condition on every system, which on `clang-native`
  and `x86_64-mingw` would be a failure.

- Line-number drift throughout, from the split: `:23` cites
  `aarch64-android21/generic.lua:108-109`, `:43` cites `generic.lua:16-18` for
  the install steps (now `generic.lua:19-21`), `:52` cites `generic.lua:9` for
  the `--without-*` list (now line 12).

- `stage1.md:16` still says `clang-native` is WILL BUILD because "even
  `--without-ssl` links", and `:36-41` still frames the package as unable to be
  combined with `packages/openssl` because of the API-21 `stderr` wall. Both
  sentences belong to the old unconditional flag. What remains true is narrower:
  a static link against *this prefix's* OpenSSL fails below API 23, which is why
  `android.lua` does not require `openssl` at all.

I am not permitted to edit `stage1.md`, so the above is recorded rather than
  fixed.

### Not fixed, and out of the adder's hands

- The mingw `libzlib` name-mismatch recorded in "One latent problem worth
  recording" above is still unaddressed. That section said it was latent and not
  required, so this is not a rework defect — but note that moving TLS onto
  `clang-native` and `x86_64-mingw` makes those two rows more likely to be built,
  and the mingw row is the one where `-lz` silently resolves to nothing. If a
  mingw build ever reports "curl: no zlib support", the fix is the `libz.* →
  libzlib.*` symlink `packages/libpng` uses, with a comment — not a flag change.

### Broken by the rework

Nothing in the recipe. The only casualty is the forecast's coherence.

## Rework verification — summary

All three required changes are correctly and completely applied: the real
  template `lib/curl_config.h.in` is guarded in both files, `--without-ssl` now
  lives only in `android.lua`, and that one file is reachable from all 56
  Android systems through `recipe_fallbacks` while `clang-native` and
  `x86_64-mingw` correctly get TLS. Rejected because `stage1.md` was not updated
  with the recipe: it still quotes the deleted comment, still claims
  `generic.lua` passes `--without-ssl`, and at `stage1.md:15` states the exact
  opposite of what the split was for.
