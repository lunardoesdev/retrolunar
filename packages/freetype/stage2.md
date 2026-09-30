REJECT

# freetype 2.13.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`freetype-2.13.3` tarball. I did not build.

**Adder B's finding #2 is CORRECT**, and it is the most valuable thing in this
package. freetype is not on the LFS list, so `topackage.md` records no verdict
for it at all — it exists only as a dependency of harfbuzz, which means the
recipe has never been recorded as built and the defect is live.

## The defect, verified against the tarball

`packages/freetype/generic.lua:8-11`:

```
        meson setup build $MESON_FLAGS \
            -Dzlib=system -Dpng=enabled \
            -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled \
            -Dtests=disabled
```

No `-Ddefault_library=static`. AGENTS.md requires it: *"Meson recipes: pass
`-Ddefault_library=static` (meson builds shared by default, and a target prefix
has no loader path for a versioned object)"*. I checked what freetype's own
build says:

```
$ grep -rn default_library meson.build meson_options.txt
meson.build:23:#   meson setup -Ddefault_library=shared     <- a comment
meson.build:305:    default_options: 'default_library=static')
```

`meson.build:305` is the `subproject('zlib', …)` call — that is freetype's
*own* default when it is built **as a subproject of harfbuzz**, which is
exactly why harfbuzz's build is static. Standalone, nothing overrides meson's
built-in `shared`. So `meson setup` here produces **`libfreetype.so.6` with a
SONAME**, the only shared library in the prefix apart from binutils and
gettext, with no rpath and no loader path arranged for it.

Every option name in the recipe is real — I checked `meson_options.txt`:
`brotli`, `bzip2`, `harfbuzz`, `mmap`, `png`, `tests`, `zlib`, all
`type: 'feature'` with `value: 'auto'`. So the recipe is passing switches
freetype actually has. The only thing wrong is the one it omits.

`packages/fribidi/generic.lua:9-13` is the worked example and does it right,
with the reason written out. Copy that shape.

## Required changes

### 1. `packages/freetype/generic.lua:8-12` — add the flag, and say why

Replace lines 8-12 with:

```
        # Static library, headers, freetype2.pc. default_library=static
        # because meson builds shared by default and a target prefix has no
        # loader path for a versioned object. Note freetype's own
        # default_options at meson.build:305 applies only when freetype is a
        # subproject (harfbuzz), never standalone, so it must be set here.
        # -Dtests=disabled drops ftdump/ftbench and the test programs, which
        # are the only executables this build produces.
        # -Dbrotli/-Dbzip2/-Dharfbuzz=disabled leave zlib and png as the only
        # backends; both come from this prefix.
        meson setup build $MESON_FLAGS -Ddefault_library=static -Dzlib=system -Dpng=enabled -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dtests=disabled
        ninja -C build
        ninja -C build install
```

The two `ninja` lines may be joined into one; splitting them matches
`packages/fribidi/generic.lua:14-15`. **Do not add `DESTDIR`** — `$MESON_FLAGS`
already carries `--prefix=$OUT` and `DESTDIR` would concatenate into
`$OUT$OUT`. `stage1.md` is right to want that confirmed, and fribidi's build is
the confirmation.

### 2. `packages/freetype/stage1.md:6` and `:67` — `bin/freetype-config` is not installed

Both lines claim it. It is not:

```
$ grep -rn "freetype-config" meson.build
(no output, exit 1)
```

The meson build installs headers, the config headers, `builds/unix/freetype2.m4`
and the `freetype2.pc` (`meson.build:431-452`) — no `freetype-config` script.
That is an autotools-only artifact. Delete the claim from the "Installs" line
and from "How to verify".

### 3. `packages/freetype/stage1.md:6` — do not write `lib/libfreetype.a` as a fact

The line currently reads "`lib/libfreetype.a` (static, via `-Ddefault_library`
default — see risks)", which asserts the artifact before admitting it may not
be. After change 1, `lib/libfreetype.a` is correct and the parenthetical should
go away entirely.

### 4. `packages/freetype/stage1.md:11-14` — the WILL BUILD rows are fine, keep them

`-Dtests=disabled` really does remove the only executables, and freetype's
platform calls (`unistd.h`, `fcntl.h`, `sys/mman.h`, `mmap`) are all in Bionic
at API 21. The forecast is right on the substance. Only the artifact list needs
fixing.

## One latent problem the forecast does not mention

`-Dzlib=system` makes meson do `dependency('zlib', required: true)`
(`meson.build:310-312`). On `x86_64-mingw` this resolves, but to the wrong
library. zlib's own CMakeLists only renames its output on `UNIX`:

```
$ # zlib-1.3.1/CMakeLists.txt:170-172
if(UNIX)
    set_target_properties(zlib zlibstatic PROPERTIES OUTPUT_NAME z)
```

With `CMAKE_SYSTEM_NAME Windows`, `UNIX` is false, so mingw gets
**`libzlib.a`** — while the installed `zlib.pc` still says `Libs: -lz`. That is
the exact name-mismatch trap AGENTS.md records, and `packages/libpng` already
works around it by symlinking `libz.* → libzlib.*` in `$PREFIX` first. curl
(reviewed separately) walks into the same hole. It does **not** fail freetype's
own build — meson's pkg-config dependency does not link-test, and freetype
builds a library — so this is a record-and-fix-later item, not a blocker. But
if a mingw consumer ever fails to link, this is why, and the fix belongs in
`zlib`'s recipe, not freetype's.

## `topackage.md`

freetype has no line of its own. It is not an LFS package, so there is nothing
to flip. If the tree wants the build recorded, the honest place is the line
that already references it — `topackage.md:196` mentions "the FreeType and
FriBidi integrations from this prefix" in the harfbuzz entry. That entry should
not be edited until freetype has actually built.

## Carried to the build

- `lib/libfreetype.a` — `llvm-objdump -f lib/libfreetype.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **`lib/libfreetype.so*` must be absent** — its presence means `-Ddefault_library=static` is still missing and the recipe must not be recorded as built.
- `include/freetype2/ft2build.h`, `include/freetype2/freetype/freetype.h` — `[ -f include/freetype2/ft2build.h ] && [ -f include/freetype2/freetype/freetype.h ]`.
- `lib/pkgconfig/freetype2.pc` — `pkg-config --modversion freetype2` → `2.13.3`. If this fails on `x86_64-mingw`, suspect the `libz`/`libzlib` naming above.
- `bin/freetype-config` must be **absent**; `bin/ftdump` and `bin/ftbench` must be **absent** — either appearing means `-Dtests=disabled` did not take.
