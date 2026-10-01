REJECT

# nettle 3.9.1 — review

Two defects: a **flag that does not exist** in the recipe, and a **version
that is three years stale** with a source comment making a claim about the
network that is wrong. The config-template question — the one you asked me
to confirm — is answered correctly, and the mirror genuinely serves the
real tarball.

## Defect 1 — `--with-pic` is not a nettle option (the recipe's own flag)

`generic.lua:22` passes `--with-pic`. nettle has no `--with-pic`. Its PIC
control is `--enable-pic` / `--disable-pic`:

```
configure.ac:60:AC_ARG_ENABLE(pic,
configure.ac:61-62:  AC_HELP_STRING([--disable-pic],
                        [Do not try to compile library files as position independent code]),,
$ ./configure --help | grep -i pic
  --disable-pic           Do not try to compile library files as position
```

Every other flag the recipe passes is real — `--disable-shared`
(`configure.ac:56`), `--enable-static` (`:52`), `--disable-mini-gmp`
(`:120`), `--disable-documentation` (`:73`). `--with-pic` is the odd one
out, and autoconf's `--with-*` handler does not match an `--enable-*`
option, so it is silently collected as unrecognized:

```
$ ./configure --with-pic --disable-shared --enable-static \
      --disable-mini-gmp --disable-documentation --prefix=/tmp/out
configure: WARNING: unrecognized options: --with-pic
configure: WARNING: unrecognized options: --with-pic
```

It does not fail — it warns and continues — which is the worst outcome, and
the one AGENTS.md calls out directly: "A nonexistent flag is worse than a
missing one — configure warns and the recipe looks deliberate." The recipe
looks like it is pinning PIC; it is not. And it is not merely cosmetic:
`configure.ac:60-62` is written so that **PIC is on by default** and
`--disable-pic` turns it *off*, so today's build happens to produce the
position-independent code the recipe was reaching for. The intent is
satisfied by accident and the comment implies otherwise.

**Required fix:** drop `--with-pic` from the flag list. PIC is nettle's
default; do not pass a switch for it. If the adder wants it stated
positively, `--enable-pic` is the real spelling and is a no-op.

## Defect 2 — the version is not current, and the source comment is wrong

`source.lua:1-2` says:

```lua
-- ftp.gnu.org is slow/unreachable from this host for some versions;
-- mirrors.kernel.org carries the identical 3.9.1 tarball and responds.
```

I reproduced the network half — `ftp.gnu.org` genuinely is unreachable from
this host:

```
$ curl --max-time 20 https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz.sig
curl: (28) Connection timed out after 20001 milliseconds
```

The mirror claim is also true, and I verified the tarball is byte-identical
to a second independent GNU mirror:

```
ccfeff981b0ca71bbd6fbcb054f407c60ffb644389a5be80d6716d5b550c6ce3  nettle.tar.gz          (mirrors.kernel.org)
ccfeff981b0ca71bbd6fbcb054f407c60ffb644389a5be80d6716d5b550c6ce3  nettle-do.de.tar.gz   (mirror.dogado.de)
```

So the *checksum is real* and the *version served is real*. But **3.9.1 is
not the current nettle**. The directory listing shows:

```
nettle-3.9.1.tar.gz     01-Jun-2023      <-- pinned here
nettle-3.10.2.tar.gz    26-Jun-2025
nettle-4.0.tar.gz       05-Feb-2026      <-- current, a major release
```

3.10 shipped two minor series after 3.9.1 and 4.0 is a new major whose
`NEWS` opens "NEWS for the Nettle 4.0 release … This is a new major
release." Pinning 3.9.1 is three years and four releases behind.

**Required fix:** bump to 3.10.2, or to 4.0 if the adder judges the API
break acceptable (4.0's `NEWS` warns that "the `*_digest` functions no
longer take the desired digest size as argument" — a consumer-visible ABI
and API change worth a deliberate decision, not a silent bump). Whichever is
chosen, the network comment should say what it actually observed rather
than generalising from "some versions".

**Before bumping, re-verify the two claims below against the new tarball** —
that is exactly the kind of thing a version bump invalidates.

## What you asked me to confirm, and the answers

**The config template is genuinely top-level `config.h.in`, and the
singular spelling is real.** Confirmed in the unpacked tree:

```
configure.ac:9:  AC_CONFIG_AUX_DIR([.])
configure.ac:11: AC_CONFIG_HEADER([config.h])
$ ls -l config.h.in aclocal.m4 configure Makefile.in
-rw-r--r-- 25698  Makefile.in
-rw-r--r-- 15776  aclocal.m4
-rw-r--r--  7912  config.h.in
-rwxr-xr-x 256816  configure
$ find . -name 'config.h.in' -o -name '*.hin'
./config.h.in
```

Exactly one template, at the top level. `generic.lua:25`'s guard
(`touch aclocal.m4 configure config.h.in`) names the right file, and it
sits **after** `./configure` and **before** `make`, which is the required
position. `find . -name 'Makefile.in' | xargs touch` is the right sweep;
`Makefile.in`'s own `SUBDIRS = tools testsuite examples` confirms
subdirectory Makefiles exist and need touching.

**Does the deprecated singular spelling matter here? No, and the reason is
worth writing down.** `AC_CONFIG_HEADER` (singular) has been deprecated in
autoconf since 2.50 in favour of `AC_CONFIG_HEADERS`, and newer autoconf
warns on it. It is irrelevant in this recipe for three concrete reasons:

1. The tarball **ships generated output** — `configure` (256 KB),
   `aclocal.m4`, `config.h.in` and `Makefile.in` are all present and
   non-empty (see the `ls -l` above). Nothing runs `autoconf` or
   `autoheader`; `make` calls `config.status`, not `autoheader`, so the
   deprecation warning is never emitted.
2. The guard's whole purpose is to make the timestamp newer than the
   shipped `aclocal.m4`/`configure`/`config.h.in` so make does **not** try
   to re-run `aclocal-1.17` — which is not installed here. Touching those
   three files is precisely what suppresses that.
3. The recipe never invokes autotools at all, so there is no deprecation
   to see.

The spelling becomes a real concern only on a bump to a nettle release
that ships `configure.ac` without generated files — which would need an
`autoreconf`, exactly as mpg123's recipe (incorrectly) tries to do. Re-check
on the version bump.

**`AC_CONFIG_AUX_DIR([.])` — stage1 is right**, the aux scripts are at the
top level and there is no separate `build-aux/` to guard.

## Question 1 — is it using the system?

Mostly yes. `./configure $AUTOCONF_CONFIGURE_FLAGS` correctly pulls
`--host=$HOST_TRIPLET --build=$BUILD_TRIPLET --prefix=$OUT` from
`packages/aarch64-android24/generic.lua:111-113`, and GMP is found through
the prefix's `PKG_CONFIG_LIBDIR`, which the system exports. No `export` of a
search flag in the recipe; no hardcoded prefix or triplet. `make -j1` is
written explicitly (allowed, and here merely explicit since bare `make`
already defaults to serial).

## Question 2 — everything else holds

- `require("gmp")` resolves — `packages/gmp/` exists. `--disable-mini-gmp`
  is real (`configure.ac:120`) and forces the prefix's GMP over the bundled
  shim, as `configure.ac:2840-2850` shows.
- `configure.ac:1234` is indeed `AC_CONFIG_FILES([nettle.pc hogweed.pc
  libnettle.map libhogweed.map])`, and both `nettle.pc.in` and
  `hogweed.pc.in` ship — stage1's line citation is correct.
- **No host programs run.** This is nettle's most likely rule violation and
  stage1 handles it correctly. `Makefile.in:22` is
  `SUBDIRS = tools testsuite examples`, but `testsuite/Makefile.in:82` is
  `all: $(EXTRA_TARGETS)` and the ~100 `*-test` programs are collected into
  `TS_ALL`, reachable only from `check:` at `testsuite/Makefile.in:125`.
  `make` and `make install` therefore build and run nothing from the
  testsuite. Correct, and worth keeping written down.
- `--enable-public-key` left at its default (`configure.ac:44-45`,
  `enable_public_key=yes`) is right: it is nettle's own code.

## Forecast — the UNCERTAINs are real, and the WILL BUILDs are not optimism

The four UNCERTAINs (three Android levels and mingw) are honest and the
stated reason is the right one. I confirmed the shape of it: nettle's
`configure.ac:48-49` defaults `enable_assembler=yes`, and the tree carries
a large hand-written assembly layer (`x86_64/`, `arm/`, `aarch64/`, `arm/neon/`
m4-processed to aarch64). "I have not assembled any of it" is a true
statement about what was and was not verified, not a hedge.

Two things sharpen it, both of which I checked rather than took on trust:

- The specific thing that would break an Android row is **not** libc at all
  — the `x86_64-android35` and Android rows share one unknown, and it is the
  assembler. nettle's `configure.ac` prefers a real `as`; with
  `AS="$CC"` from `packages/aarch64-android24/generic.lua:47` the NDK's
  integrated assembler is what it gets. If it rejects any nettle
  instruction form, that is the first diagnostic a builder will see. That is
  a specific, nameable failure, which is what makes the UNCERTAIN useful.
- The `clang-native` WILL BUILD is the one row with essentially no
  uncertainty: native x86_64 with the system assembler is the configuration
  nettle's own CI covers most, and it is not the assembly per se that is in
  doubt on that row.

The `x86_64-android35` row is marked "WILL BUILD (moderate confidence)" and
gives its reason honestly ("I did not check whether nettle's x86_64 path
reaches for an assembler feature the NDK clang's integrated assembler
lacks"). That is the same uncertainty as the other three rows wearing a
WILL BUILD hat. It is not wrong — x86_64 is genuinely nettle's
best-trodden architecture — but it is the one row where the stated
confidence and the stated unknown disagree, and a builder reading the table
should know that the unknown applies there too. Noted, not a reject on its
own.

## Carried to the build

Scoped to nettle's own artefacts. The `llvm-nm | grep -c` filter is
anchored on `__gmp`, which only nettle's own undefined references can
produce, and the expected value is stated.

```sh
# 1. Both archives.
[ -f lib/libnettle.a ]
[ -f lib/libhogweed.a ]

# 2. Headers, including one from each library.
[ -f include/nettle/aes.h ]
[ -f include/nettle/version.h ]
[ -f include/hogweed/curve25519.h ]

# 3. The .pc files stage1 promises.
pkg-config --modversion nettle            # expected 3.9.1 (or the bumped version)
[ -f lib/pkgconfig/nettle.pc ]
[ -f lib/pkgconfig/hogweed.pc ]

# 4. --disable-mini-gmp worked: the archive resolves GMP symbols against
#    the prefix's libgmp rather than carrying nettle's own shim.
llvm-nm --undefined-only lib/libnettle.a | grep -c '__gmp'   # expected 0

# 5. No shared object, and no liblzma crept in.
[ ! -e lib/libnettle.so ]
llvm-nm --undefined-only lib/libnettle.a | grep -c 'lzma_'   # expected 0

# 6. Right machine for the target.
readelf -h lib/libnettle.a | grep Machine
```

Check 4 is the one that would catch a silently-ignored `--disable-mini-gmp`,
and its expected value of **0** is stated explicitly so a builder does not
invert it. Checks 4 and 5 are each scoped to a symbol prefix nettle's own
archive would carry, so a second package cannot satisfy them.
