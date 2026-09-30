# texinfo build forecast — status uncertain; recorded blocker is stale

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 7.3 (`ftp.gnu.org/gnu/texinfo/texinfo-7.3.tar.xz`)
- Build system: **autotools** with *nested* configures — `./configure` at
  `generic.lua:7`, timestamp guard at `:8-9`, plus a second `find … |
  xargs touch` at `:11` specifically for the nested `config.status` files
- Would install: `bin/texi2any`, `bin/makeinfo`, `bin/info`, `bin/install-info`,
  `bin/makehtml`, `bin/makeinfo --html`, and `info/` documentation. No library,
  no `.pc`.
- Requires: `texinfo@source` only (`generic.lua:1`)

**Host-tool dependency worth watching:** the recipe hardcodes
`/usr/bin/cc`, `/usr/bin/ar` and `/usr/bin/ranlib` at `generic.lua:7`, because
texinfo's nested `tta/` configure wants a *build-host* compiler. That is the
same shape as `perl@native` in `packages/xml-parser` and `gperf@native` in
`packages/bison`, and it would be more robust as `require("...@native")` so
the prefix's own host toolchain is used instead of assuming GCC at a fixed
path. Deliberately not changed here: it restructures the recipe's dependency
graph and deserves its own reviewed change. The practical consequence today
is that the build assumes a C compiler at exactly that path on the build
host, and the UNCERTAIN rows below turn on whether that is good enough.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | The recipe now attempts the cross build with `BUILD_CC`; whether texinfo 7.3's `install-info` probe survives is untested. See below. |
| aarch64-android24 | UNCERTAIN | As above. |
| aarch64-android35 | UNCERTAIN | As above. |
| x86_64-android35 | UNCERTAIN | As above. |
| x86_64-mingw | UNCERTAIN | Same nested-configure structure; `/usr/bin/cc` on the build host is a Linux compiler, so the mingw rows depend on the same mechanism working with a different `$CC`. |
| clang-native | WILL BUILD | Native; the nested configures have no problem to solve. |

**This is a forecast that contradicts the backlog, which is the useful finding
here.**

`topackage.md:81` records: "Texinfo 7.3 (LFS 7.2; blocked: nested tta
configure falls back to cc and cannot create executables)". **The recipe no
longer matches that description.** Read `generic.lua:7`:

```
PATH="/usr/bin:/bin:$PATH" BUILD_CC=/usr/bin/cc BUILD_AR=/usr/bin/ar \
  BUILD_RANLIB=/usr/bin/ranlib ./configure $AUTOCONF_CONFIGURE_FLAGS
```

and `generic.lua:10-11`:

```
# Keep nested config.status newer to prevent make from reconfiguring native helpers.
find . -name config.status | xargs touch
```

Both of those are **aimed squarely at the recorded blocker**. The recorded
failure was that a nested configure (upstream's `tta`, the build-tool
accelerator for the `makeinfo`/`texi2any` hierarchy) fell back to a bare `cc`
and could not create target executables. The recipe answers that by pinning
`BUILD_CC`, `BUILD_AR` and `BUILD_RANLIB` to the host tools and putting
`/usr/bin:/bin` ahead of the cross toolchain on `PATH` — the standard gnulib
"cross-compile the build tools natively" mechanism. The second `touch` exists
because touching `configure`/`Makefile.in` (lines 8-9) also makes the nested
`config.status` stale, which would make make re-run exactly the nested
configure the recipe is trying to suppress.

So either the recipe fixes the recorded blocker, or it fails somewhere the
backlog never got to. **I am not claiming it builds** — I cannot configure or
run it — but the backlog's blocker text no longer describes the code in front
of me, and a reviewer should re-test it rather than treat it as settled.
`topackage.md` is not mine to edit; flagging it here as instructed.

**API level notes.** No Bionic symbol gate is implicated. The recipe is about
*which compiler builds the build tools*, not about what the target may call.
Two API-level-adjacent notes for the record, neither a blocker: texinfo's
`install-info` edits shell startup files and uses `getpwuid`/`getenv`, both
present at API 21; and the `PATH` prepend at `generic.lua:7` deliberately puts
**host** tools ahead of the cross toolchain for the nested configures, which is
the opposite of what AGENTS.md:320-325 mandates for a *system* recipe — but it
is scoped to a nested build-tool configure inside one recipe, which is exactly
the kind of recipe-local workaround AGENTS.md's exception allows, provided the
comment says why. It does (`generic.lua:6`).

**Risks / what a reviewer should check.**
1. **The nested-configure mechanism is the whole ballgame.** If texinfo 7.3's
   `tta` configure ignores `BUILD_CC` (it is an old-style nested
   `config.cache`-driven build), the recipe does nothing useful and the
   original blocker stands. **What would settle it:** run the recipe and look
   for the host compiler appearing in the nested `config.log`.
2. **`PATH="/usr/bin:/bin:$PATH"` is a broad hammer.** It affects the whole
   recipe body, including any step that should use the cross toolchain by
   name. Since `$CC`/`$CXX` are absolute NDK paths and are not looked up on
   `PATH`, this is safe as written — but it is the kind of line that breaks
   silently if someone later switches `$CC` to a bare name.
3. `make` at `generic.lua:12` is bare (serialises by default); cosmetic, as in
   `sed`, `tar`, `shadow`, `sysklogd`, `util-linux`, `xz`.
4. No `.pc`; `bin/` tools only.

**How to verify once built.**
- `bin/texi2any`, `bin/makeinfo`, `bin/info`, `bin/install-info`
- `file bin/texi2any` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for
  Android <level>`
- `llvm-objdump -f bin/texi2any | head` → `elf64-littleaarch64` on aarch64
- **The decisive check that the cross build actually happened:** build it, then
  confirm the nested build tools are *not* in `$PREFIX` (they are host
  binaries and must never be installed). `find $PREFIX -type f -executable |
  xargs file | grep 'x86-64'` must come back empty.
- `strings bin/makeinfo | grep -m1 texinfo` for the version stamp