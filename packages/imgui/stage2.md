ACCEPT

# imgui 1.92.9 — stage 2 review

Checked against the unpacked `imgui-1.92.9` tree in `$HOME/dl`.

## "No build system at all" — verified

```
$ ls imgui-1.92.9/
LICENSE.txt backends docs examples imconfig.h imgui.cpp imgui.h imgui_demo.cpp
imgui_draw.cpp imgui_internal.h imgui_tables.cpp imgui_widgets.cpp
imstb_rectpack.h imstb_textedit.h imstb_truetype.h misc
```

No `CMakeLists.txt`, no `Makefile`, no `configure`, no `configure.ac`. The
package really is four translation units plus headers, so `mkdir` + `$CXX` +
`$AR` is the whole build. The recipe's shape is right and matches
`packages/lua/generic.lua`, which the comment cites.

## Every file the recipe names exists

This is the check that catches the "a glob that cannot match its own target"
failure, so I listed the tree rather than trusting the list:

- **Sources:** `imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp` —
  all four present.
- **Headers copied:** `imgui.h imgui_internal.h imconfig.h imstb_rectpack.h
  imstb_textedit.h imstb_truetype.h LICENSE.txt` — all seven present, in that
  exact spelling.
- **Version:** `imgui.h:32` is `#define IMGUI_VERSION "1.92.9"`, matching the
  pinned version. The `.pc` heredoc says `Version: 1.92.9`. Consistent.

So the `for` loop and the `cp` list can both succeed. stage1.md:44-52 also
catches the `stb_sprintf.h` trap correctly: `imgui.cpp:2338-2342` includes a
file `misc/cpp/` does not ship, but it is behind `#ifdef IMGUI_USE_STB_SPRINTF`
which nothing here defines, so it never fires. Good catch, and it is the kind
of thing that would have surfaced as a confusing build failure later.

## The host-dependency claim, verified

```
$ grep -n "^#include <" imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp | grep -v '"imgui'
imgui.cpp:1257:#include <stdio.h>
imgui.cpp:1258:#include <stdint.h>
imgui.cpp:1260:#include <time.h>
imgui.cpp:1283:#include <Windows.h>      (_WIN32)
imgui.cpp:1285:#include <windows.h>      (_WIN32)
imgui.cpp:1297:#include <TargetConditionals.h>  (__APPLE__)
imgui.cpp:16215:#include <Carbon/Carbon.h>     (__APPLE__)
imgui.cpp:16303:#include <shellapi.h>   (_WIN32)
imgui.cpp:16316-16317: <sys/wait.h>, <unistd.h>
imgui.cpp:16350:#include <imm.h>         (_MSC_VER)
imgui_draw.cpp:43-44, imgui_tables.cpp:205, imgui_widgets.cpp:48: <stdio.h>/<stdint.h>
```

Every system header outside the core three sits behind `_WIN32`, `__APPLE__`
or `_MSC_VER`. The only platform call is `localtime_r()` (`imgui.cpp:4490`),
present in Bionic at every API level, and `imgui.cpp:1261-1263` provides a
`localtime_s` shim for Windows. **No API gate applies at any level**, which is
what the forecast says and what the grep supports.

## The system

```sh
for _s in imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp; do
  $CXX $CXXFLAGS -c "$_s" -o "obj/${_s%.cpp}.o"
done
$AR rcs $OUT/lib/libimgui.a obj/*.o
$RANLIB $OUT/lib/libimgui.a
```

`$CXX`, `$CXXFLAGS`, `$AR`, `$RANLIB` all from the system — no hardcoded
compiler, no `export`, no search flags added by hand. The only build-body
verbs are `mkdir`, `cp` and `cat`, all on the AGENTS.md:223-225 allowed list.
`$AR rcs` is sequential and does not fan out. The hand-written `.pc` follows
the `packages/lua/generic.lua` precedent, and since it is written under
`$OUT/lib/pkgconfig/` the loader's `$OUT`→`$PREFIX` rewrite
(`src/loader.lua:454-468`) applies to it automatically — nothing to do.

`require("imgui@source")` only. Correct: no external header, library or host
program is referenced.

## No target binary is executed

There is no build system to run anything. `$CXX` only compiles; `$AR` and
`$RANLIB` only archive. The `backends/`, `examples/`, `misc/freetype` and
`misc/cpp` trees are not compiled at all, so the 19 backend glue files and 30
example programs that would need X11/Wayland/GL/SDL are simply absent from the
build. Clean.

## One note on the C++ dialect

stage1.md:150-152 flags that the package does not pin a C++ dialect, and that
as the thing a real build would confirm first. I agree that it is the open
question, and I would rather name it than pretend it is settled. The NDK
wrappers default well above the C++11 floor Dear ImGui documents in
`docs/compile.md`, and mingw's g++ likewise, so the risk is low — but "low"
is not "verified", and the builder should treat the first compile as the
answer. This is correctly disclosed in the forecast and is not a defect.

## The deliberate omission, stated honestly

The recipe builds neither `imgui_demo.cpp` nor anything in `backends/`, and
says so. `imgui_impl_glfw.cpp` would pair with the `glfw` package, but glfw
itself builds only its null backend on these targets (see
`packages/glfw/stage2.md`), so the pairing would not produce a usable window
either. Omitting `backends/` is the right call for a prefix with no display
server, and the comment says exactly that rather than claiming the library is
feature-complete. stage1.md:159-164 surfaces the same trade-off for the
reviewer. Good.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. mingw is the only row with any branching, and it is handled
in-source behind `_WIN32` (`<windows.h>` and the `localtime_s` shim, both
provided by mingw-w64), not by a build-system switch — so the recipe needs no
`android.lua` and none exists. The Win32 clipboard/IME defaults need no
link-time library at compile time, which is the right observation to make
about them.

## Verdict

ACCEPT. The simplest recipe in the batch and the most honest: no build system
claimed and none present, every named file verified to exist, the entire host
surface reduced to `<stdio.h> <stdint.h> <time.h>` plus `localtime_r`, all
tools from the system, no target binary executed, and the one real judgement
call — omitting `backends/` — argued in the open rather than buried. The
unpinned C++ dialect is disclosed as the open question rather than asserted
away.
