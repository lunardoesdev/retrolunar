ACCEPT

# glew 2.3.1 — stage 2 review

Checked against the unpacked `glew-2.3.1` tree in `$HOME/dl`, plus a compile
probe of `src/glew.c` under upstream's own flags.

## The build-system choice is right, and I confirmed the mechanism

The claim is that `build/cmake/CMakeLists.txt:39` is
`find_package(OpenGL REQUIRED)` with the result linked into both library
targets (`:157-158`), so the CMake path cannot configure in this tree, whereas
the hand-written makefile never probes for GL at all. Both halves check out:

- `Makefile:86` — the default goal `all debug: glew.lib glew.bin`, i.e. shared
  **and** static **and** two host programs.
- `Makefile:122-123` — the shared link is `$(LD) $(LDFLAGS.SO) -o $@ $^
  $(LIB.LDFLAGS) $(LIB.LIBS)`, and `config/Makefile.linux:22` sets
  `LDFLAGS.GL = -lGL -lX11`. Neither library exists in this prefix.
- `config/Makefile.linux:2-3` — `CC = cc` / `LD = cc` with a plain `=`, which
  **overrides the environment**. So the recipe's command-line `CC="$CC"` is
  genuinely load-bearing, exactly as claimed: without it every object would be
  built with the host `cc`.
- `Makefile:50` — `ifneq ($(GLEW_NO_GLU), -DGLEW_NO_GLU)` / `LIBGLU = glu`, and
  `Makefile:154` substitutes `$(LIBGLU)` into `@requireslib@`, which lands in
  `glew.pc.in:11` `Requires: @requireslib@`. Passing the literal
  `GLEW_NO_GLU=-DGLEW_NO_GLU` leaves it empty. There is no `glu.pc` in this
  prefix, and a `Requires:` naming a missing module makes `pkg-config` fail
  outright. Correct.
- `Makefile:43-44` — `GLEW_PREFIX ?= /usr/local` / `GLEW_DEST ?= /usr/local`.
  Both passed as `$OUT`.
- `config/Makefile.linux:1-21` — `LIBDIR` is chosen from `M_ARCH ?= $(shell
  uname -m)` of the **build** host; `x86_64` selects the `ARCH64 = true` branch
  and `LIBDIR = $(GLEW_DEST)/lib64`. Passing `LIBDIR="$OUT/lib"` is therefore
  load-bearing for every 32-bit target and for the `.pc`'s `libdir=`.

`LDFLAGS.GL=` is also right, and for the same reason: `Makefile:153`
substitutes `$(LDFLAGS.GL)` into `@libgl@`, so leaving `-lGL -lX11` in would
hand both to every consumer via `pkg-config --libs glew`.

## The compile probe

stage1.md:146-151 flags `-ansi -pedantic` (`config/Makefile.linux:32`) as the
most likely future source of noise and notes there is no `-Werror` anywhere. I
compiled `src/glew.c` with upstream's exact static-archive line
(`Makefile:134`: `-DGLEW_NO_GLU -DGLEW_STATIC`, plus `-O2 -Iinclude` and the
config file's `-Wall -W -Wshadow -Wcast-qual -fPIC -ansi -pedantic`):

```
RC=0
-rw-r--r-- 1 si si 1121680 ... g.o
```

Clean, exit 0, no diagnostics. The `-ansi` worry is unfounded for this
release and this compiler.

## GLEW needs no OpenGL headers — confirmed

The generated source is the only one, and its includes are its own headers plus
`<stddef.h>` and `<dlfcn.h>`. `src/glew.c:60` excludes `__ANDROID__` from the
GLX branch, and I confirmed the NDK wrappers predefine `__ANDROID__`
unconditionally:

```
$ echo 'int x[__ANDROID__ ? 1 : -1];' | aarch64-linux-android24-clang -c
predefined __ANDROID__ yes
```

So on Android not even `GL/glxew.h` is opened. `include/GL/` does contain all
four headers the recipe copies (`eglew.h glew.h glxew.h wglew.h`), so the
`cp` list matches what is on disk — the check can succeed.

## The system

```
make -j1 glew.lib.static CC="$CC" AR="$AR" RANLIB="$RANLIB" STRIP= \
  GLEW_DEST="$OUT" GLEW_PREFIX="$OUT" LIBDIR="$OUT/lib" \
  LDFLAGS.GL= GLEW_NO_GLU=-DGLEW_NO_GLU
```

Every toolchain value from the system, passed on the make line because the
config files override the environment — the right delivery mechanism for this
build system, and the comment explains it. `STRIP=` is upstream's own documented
way to disable stripping (`Makefile:61-66`; the guard is `ifneq ($(STRIP),)`
at `:118`), which is correct: the default `strip` is the **host** strip and
must never touch a cross archive. `make -j1` explicit. No fan-out, no
`export`, no hardcoded target facts.

`require("glew@source")` only, which is right: nothing external is referenced
by a static archive.

## No target binary is executed

`glew.lib.static: lib lib/$(LIB.STATIC) glew.pc` (`Makefile:105`) — its
prerequisites are the `mkdir lib` target, the archive, and the `.pc`. The
archive depends on `$(LIB.OBJS)`, one `.c` file. The `.pc` rule runs `sed`,
a **host** tool, over `glew.pc.in`. That is not a target binary; it is sed
running on the build machine, which is fine. `glewinfo` and `visualinfo` are
never built — the recipe asks for `glew.lib.static`, not `all` or `glew.bin`.
Clean.

## Two notes, neither a defect

- **`SYSTEM` resolves to `linux` on this host**, so
  `config/Makefile.linux` applies to *every* target including mingw. I
  confirmed the resolution: `config/config.guess` → `x86_64-pc-linux-gnu` →
  `cut -d - -f3 | sed -e 's/\.//g' -e 's/[0-9]\{1,\}.*//'` → `linux`.
  stage1.md:138-147 discusses this and reaches the right conclusion: using
  `config/Makefile.linux-mingw64` would bake `CC := x86_64-w64-mingw32-gcc`
  into the recipe and rename the artifact `libglew32.a`, so overriding the
  variables on the command line for all targets is the correct trade. The
  mingw artifact is therefore `libGLEW.a` under `$OUT/lib`, consistent with
  every other package here.
- **The `.pc` gets the loader's `$OUT`→`$PREFIX` rewrite for free**
  (`src/loader.lua:454-468` walks `"$OUT"/lib/pkgconfig/*.pc`), since the
  recipe writes it there. Nothing to do, correctly not claimed as a step.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. mingw: `_WIN32` selects `<GL/wglew.h>` (GLEW's own header) and
`<dlfcn.h>` is not reached, so there is no SDK dependency at compile time. The
X11 dependency is purely link-time and the link is suppressed.

## Verdict

ACCEPT. Choosing the hand-written makefile over CMake is justified by a
mechanism I confirmed rather than accepted, every make-line variable is
load-bearing for a stated and correct reason, upstream's own `-ansi` flags
compile clean, no target binary is executed, and the artifact lands in `lib/`
with a `.pc` that names neither `libGL`, `libX11` nor a missing `glu`.
