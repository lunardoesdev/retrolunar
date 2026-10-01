# glew 2.3.1 — stage 1 build forecast

**Package:** glew
**Version:** 2.3.1
**Upstream:** https://github.com/nigels-com/glew
**Build system:** hand-written GNU make (`Makefile` + `config/Makefile.<SYSTEM>`).
GLEW *also* ships a CMake build at `build/cmake/CMakeLists.txt`, but it cannot
configure here — see below.

A forecast from reading upstream source. Nothing has been compiled.

## "GLEW generates its source at build time and needs OpenGL headers"

**Both halves of that are false for this release, and the difference matters.**

*It can generate, but this release does not have to.* `make extensions`
(`Makefile:356-357`) recurses into `auto/`, whose `Makefile` git-clones three
upstream registries — `REPO_OPENGL ?= https://github.com/KhronosGroup/OpenGL-Registry.git`
and two siblings (`auto/Makefile:24-26`) — and then runs the Perl scripts in
`auto/bin/*.pl` over them. That is network access at build time, which
AGENTS.md forbids. The reason it can be skipped is that **`dist-src` strips the
registries out of the tarball** (`Makefile:298-301`: `rm -Rf .../auto/registry`,
`auto/OpenGL-Registry`, `auto/EGL-Registry`) — I confirmed `auto/registry` is
absent — and ships the *output* instead: `src/glew.c` (32 968 lines),
`include/GL/glew.h` (27 052 lines), `include/GL/glxew.h`, `include/GL/wglew.h`
and `include/GL/eglew.h`. The recipe never runs the generator, and could not if
it wanted to.

*It needs no OpenGL headers.* GLEW **is** the OpenGL header. Its only source is
`src/glew.c` (`Makefile:94`), whose includes are:

| Line | Content |
| --- | --- |
| `src/glew.c:34` | `<GL/glew.h>` — its own, from this tree (`-Iinclude`, `Makefile:83`) |
| `src/glew.c:60` | `<GL/glxew.h>` — guarded by `#elif !defined(__ANDROID__) && …`, its own |
| `src/glew.c:61` | `<GL/wglew.h>` — guarded by `#elif defined(_WIN32)`, its own |
| `src/glew.c:51` | `<GL/eglew.h>` — its own, only under `GLEW_EGL` |
| `src/glew.c:66` | `<stddef.h>` |
| `src/glew.c:115` | `<dlfcn.h>` — non-Apple path |

No `<GL/gl.h>`, no `<GL/glext.h>`, no X11 headers. The only external system
header on any non-Windows target is `<dlfcn.h>`, which Bionic has from API 21.

**GLEW has explicit first-class Android support.** `src/glew.c:60` excludes
`__ANDROID__` from the GLX branch, so on Android GLEW includes only its own
`GL/glew.h` — no X11 or GLX header is even opened.

## What it installs

- `lib/libGLEW.a` — static only. `LIB.STATIC = lib$(NAME).a` with `NAME = GLEW`
  (`config/Makefile.linux:25,38`). Built by `make glew.lib.static`
  (`Makefile:105,112-120`).
- `include/GL/{glew,glxew,wglew,eglew}.h` (`Makefile:233-239`).
- `lib/pkgconfig/glew.pc`, generated from `glew.pc.in` (`Makefile:144-155`).

**No tools.** `glewinfo` and `visualinfo` are the only executables
(`Makefile:161-169,176`) and the recipe builds neither — they need a live GL
context (`Makefile:86,176-191`).

## Why the makefile and not the CMake build

`build/cmake/CMakeLists.txt:39` is `find_package(OpenGL REQUIRED)`, and its
result is linked into **both** library targets
(`build/cmake/CMakeLists.txt:157-158`). No Android sysroot, no mingw sysroot
and no glibc prefix in this tree offers a `libGL` for GLEW to find, so
configure aborts. I checked whether `CMAKE_DISABLE_FIND_PACKAGE_OpenGL` could
bypass it: cmake's own documentation for that variable says it disables
**non-REQUIRED** `find_package()` calls, so it cannot. GLEW never actually needs
an OpenGL library — it resolves GL through its own function-pointer table — and
the hand-written makefile never probes for one. That is the reason the makefile
is the correct build system here, not merely the available one.

## Switches passed, and why

Every one is a make **command-line** variable. That is load-bearing: a
command-line variable overrides a makefile assignment, and
`config/Makefile.linux:2-3` assigns `CC = cc` / `LD = cc` with a plain `=`,
which would otherwise beat the exported `$CC` and silently cross-compile with
the host compiler.

| Variable | Reason |
| --- | --- |
| `glew.lib.static` (target) | The default goal is `all` = `glew.lib glew.bin` (`Makefile:86`) — shared **and** static **and** two host programs. The shared link (`Makefile:122-123`) uses `$(LD)` with `$(LDFLAGS.GL) = -lGL -lX11` (`config/Makefile.linux:22`), neither of which exists here. |
| `CC="$CC"` | `config/Makefile.linux:2` hardcodes `CC = cc`, overriding the environment. |
| `AR="$AR"`, `RANLIB="$RANLIB"` | The systems' llvm binutils, used at `Makefile:114`. |
| `STRIP=` | `Makefile:61-66` documents `STRIP=` on the command line as the way to disable stripping; the guard is `ifneq ($(STRIP),)` at `Makefile:118`. The default `strip` is the **host** strip and must never touch a cross archive. |
| `GLEW_DEST="$OUT"`, `GLEW_PREFIX="$OUT"` | Defaults are `/usr/local` (`Makefile:43-44`). `GLEW_PREFIX` becomes `prefix=` in glew.pc (`Makefile:146`). |
| `LIBDIR="$OUT/lib"` | `config/Makefile.linux:16-21` picks `lib64` from `uname -m` of the **build** host, so on this x86_64 host every target — including 32-bit `armv7a` and `i686` — would get `lib64`. `LIBDIR` also becomes `libdir=` in glew.pc (`Makefile:147`). |
| `LDFLAGS.GL=` | Suppresses `-lGL -lX11`, which is otherwise substituted into glew.pc as `@libgl@` (`Makefile:153`) and would be handed to every consumer by `pkg-config --libs glew`. |
| `GLEW_NO_GLU=-DGLEW_NO_GLU` | `Makefile:50` is `ifneq ($(GLEW_NO_GLU), -DGLEW_NO_GLU)`; passing the literal value leaves `@requireslib@` empty instead of `glu` (`Makefile:154`). There is no `glu.pc` in this prefix, and a `Requires:` naming a missing module makes `pkg-config` fail outright. |

**No `android.lua`.** `src/glew.c:60` handles `__ANDROID__` itself, in the
source, with no build-system switch. There is nothing an `ANDROID`-only recipe
could add that the generic one does not already do.

## Dependencies

**None.** No `require()` other than `glew@source`. The only libraries the
static build can reference are `Threads`-free libc and `<dlfcn.h>`; the `-lGL
-lX11` that would break the link are suppressed by `LDFLAGS.GL=`, and a static
archive has no link step anyway.

## Source

`https://github.com/nigels-com/glew/releases/download/glew-2.3.1/glew-2.3.1.tgz`
— verified HTTP 200, and the downloaded size (866 060 bytes) matches the
server's `Content-Length` exactly. GLEW publishes three archives per release;
the `.tgz` is the source tree. Single top-level directory `glew-2.3.1`, 1540
files, 11 MB, stripped by the recipe. 2.3.1 is the newest tag.

## API-level gating

`src/glew.c` is 33 000 lines of generated C. I grepped it, and the four public
headers, for every documented wall: `process_vm_readv`, `posix_spawn`, `mblen`,
`getpass`, `O_BINARY`, `POSIX_MADV_*`, `mktime_z`, `nl_langinfo`, `iconv`,
`scandir`, `getline`, `pidfd_*`, `mktime`, `localtime`. There are **no hits**.
The only platform conditionals are `_WIN32`, `__APPLE__`, `__ANDROID__`,
`__native_client__`, `__HAIKU__`, `__sgi`, `__sun`, `_MSC_VER`, `NOGDI` — all
either compile-time feature tests or targets we are not building.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | One C file, no API-gated call, and `__ANDROID__` is handled at `src/glew.c:60` so not even the GLX header is opened. Lowest available level is not a constraint. |
| `aarch64-android24` | WILL BUILD | As above. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above; the source has no architecture branches. |
| `x86_64-mingw` | WILL BUILD | `_WIN32` selects `<GL/wglew.h>` (`src/glew.c:61` — GLEW's own header) and the `_WIN32` blocks at `src/glew.c:54-64` need no SDK header; `<dlfcn.h>` is not reached on this path. One wrinkle recorded below. |
| `clang-native` | WILL BUILD | `src/glew.c:60` selects `<GL/glxew.h>`, again GLEW's own header — no X11 SDK is needed to *compile* it. The X11 dependency in this package is purely a link-time one, and the link step is suppressed. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row,
with one exception: `LIBDIR=` is passed explicitly precisely because the
build host's `uname -m` would otherwise put their archive under `lib64`.

## What a reviewer should scrutinise

1. **`config/Makefile.linux` is applied to every target**, including mingw,
   because `SYSTEM` comes from `config.guess` on the *build* host
   (`Makefile:34-38`). Upstream's intended mingw route is
   `make SYSTEM=linux-mingw64`, but that file hardcodes
   `CC := x86_64-w64-mingw32-gcc` (`config/Makefile.linux-mingw64:11`) and
   renames the artifact to `libglew32.a` (`:8,23`). Using it would mean
   baking a target triple into the recipe. Using `linux` everywhere and
   overriding the variables on the command line keeps every target fact in the
   system file where it belongs — the cost is that mingw gets
   `-ansi -pedantic` (`:32`), which is upstream's own choice and only warns.
2. **`-ansi`** (`config/Makefile.linux:32`) is `-std=c90`, applied to
   `src/glew.c` under a modern clang. There is no `-Werror` anywhere in the
   config, so this is warnings-only — but it is the most likely place a
   future clang would emit noise, and it is upstream's, not ours.
3. **`STRIP=` leaves the archive unstripped.** That matches `ar cr` semantics
   and what Android expects; a consumer strips with its own `$STRIP`. If a
   builder prefers to pass `STRIP="$STRIP"` instead, that is a one-word change
   and is arguably better hygiene — but only if llvm-strip accepts the `-x`
   that `Makefile:119` adds.
4. **The `.pc` is genuinely clean.** With `LDFLAGS.GL=` and
   `GLEW_NO_GLU=-DGLEW_NO_GLU`, `pkg-config --libs glew` should return
   `-L$PREFIX/lib -lGLEW` and nothing else. Worth a builder confirming
   against the real generated `glew.pc`, because the loader's `$OUT`→`$PREFIX`
   rewrite (`src/loader.lua:454-468`) also applies to it.