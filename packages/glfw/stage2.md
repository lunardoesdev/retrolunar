ACCEPT

# glfw 3.5.1 — stage 2 review

Checked against the unpacked `glfw-3.5.1` tree in `$HOME/dl`, plus compiler
probes against NDK r28 at API 21 (the hardest level).

## The "null-only source set" claim, verified by compiling it

This is the claim everything rests on, and it is unusual enough that reading
the CMake files is not enough — so I compiled the exact source set the recipe
implies, with the exact flags the recipe's configuration produces
(`-std=c99` from `src/CMakeLists.txt:97-99`, plus `_DEFAULT_SOURCE` from
`:269`), against `aarch64-linux-android21-clang`:

```
null_init.c        : OK      posix_time.c     : OK
null_window.c      : OK      posix_thread.c   : OK
null_monitor.c     : OK      posix_module.c   : OK
null_joystick.c    : OK      platform.c       : OK
context.c          : OK      init.c           : OK
input.c            : OK      monitor.c        : OK
window.c           : OK      vulkan.c         : OK
egl_context.c      : OK      osmesa_context.c : OK
```

**Every file compiles clean at API 21 with no diagnostics.** The claim is
correct, and this is the strongest form of evidence available short of
building the package.

The structural claims behind it check out too:

- `src/CMakeLists.txt:1-8` — the null sources are unconditional members of the
  `add_library(glfw ...)` call itself, not inside an `if()`. Confirmed.
- `CMakeLists.txt:29-30` — `GLFW_BUILD_X11` and `GLFW_BUILD_WAYLAND` are
  `cmake_dependent_option`s conditioned on `"UNIX;NOT APPLE"`, and
  `GLFW_BUILD_WIN32` on `"WIN32"`. Confirmed.
- `src/CMakeLists.txt:176` `find_package(X11 REQUIRED)` and the
  `FATAL_ERROR`s at `:181,187,191,199,205,211` are all inside
  `if (GLFW_BUILD_X11)`. `:77`'s `FATAL_ERROR "Failed to find wayland-scanner"`
  is inside `if (GLFW_BUILD_WAYLAND)`. With both off, none is reachable.
- `src/platform.h:40` includes `null_platform.h` unconditionally, and
  `src/platform.c:78-79` short-circuits `GLFW_PLATFORM_NULL` to
  `_glfwConnectNull()`. Confirmed.

**`vulkan.c` is in the compiled set and needs no Vulkan SDK** — worth checking
explicitly, since it is unconditional in `add_library` and a Vulkan header
would have been a hard blocker. It includes only `internal.h`, `<assert.h>`,
`<string.h>`, `<stdlib.h>`, and `CoreFoundation` under `__APPLE__` only. It
resolves Vulkan through `dlopen` at runtime. Compiles clean, as the probe
above shows.

## `find_package(Threads REQUIRED)` is satisfied — but the stage1's reason is
wrong for two of the six rows

`CMakeLists.txt:48` is `find_package(Threads REQUIRED)` (confirmed). The
forecast says it is satisfied "because every system already exports
`-DTHREADS_PREFER_PTHREAD_FLAG=ON` in `$CMAKE_FLAGS`". **That is true for the
Android systems and false for the other two families:**

```
$ grep -c THREADS_PREFER packages/aarch64-android21/generic.lua   → 1
$ grep -c THREADS_PREFER packages/x86_64-mingw/generic.lua         → 0
$ grep -c THREADS_PREFER packages/clang-native/generic.lua         → 0
```

This does **not** make the recipe wrong, and it is not a REJECT: on
`x86_64-mingw` and `clang-native` the probe succeeds for the ordinary reason —
neither is a cross-compile of glibc code onto a target without pthreads, so
FindThreads' libc probe compiles and links and finds what it expects. The flag
is a Bionic workaround, and Bionic is not in play on those two rows.

It is recorded because AGENTS.md:505-508 makes a wrong justification a defect,
and because a builder reading "satisfied by THREADS_PREFER_PTHREAD_FLAG" on the
mingw row would go looking for a flag that isn't there and might "fix" the
system file. The one-line correction: the flag covers the Android rows; mingw
and native succeed natively. The recipe is unaffected either way.

## The system

```
cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DGLFW_BUILD_X11=OFF \
  -DGLFW_BUILD_WAYLAND=OFF -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF \
  -DGLFW_BUILD_DOCS=OFF
cmake --build build --parallel 1
cmake --install build
```

Every flag via `$CMAKE_FLAGS`. No hardcoded target facts, no exported search
flags, no `export`. `--parallel 1` explicit, no fan-out. `require("glfw@source")`
only — correct, since with both backends off there are no `find_package` calls
beyond `Threads`. No `android.lua`, and the comment justifies why: there is no
`if (ANDROID)` branch in GLFW's CMake to unlock. Correct.

Every option exists: `CMakeLists.txt:9-12` defines `BUILD_SHARED_LIBS` (default
OFF), `GLFW_BUILD_EXAMPLES` and `GLFW_BUILD_TESTS` (both default
`${GLFW_STANDALONE}` = ON for a top-level build) and `GLFW_BUILD_DOCS`
(default ON). No invented flags.

## No host program, no target binary executed

- `GLFW_BUILD_EXAMPLES=OFF` and `GLFW_BUILD_TESTS=OFF` remove 33 host programs
  that would otherwise be cross-compiled. `GLFW_BUILD_DOCS=OFF` removes the
  Doxygen ≥ 1.9.8 requirement (`docs/CMakeLists.txt:3`).
- `add_custom_target(update_mappings ...)` at `src/CMakeLists.txt:20-26` runs
  cmake at build time over `mappings.h.in` — but it is a custom *target*, not
  in `ALL`, so `cmake --build` does not build it. `mappings.h` ships in the
  tree. Nothing runs.
- Nothing in the compiled set executes anything.

Clean.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes (compiled the set myself) |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. The mingw row is right for the reason stage1:143 gives —
`CMAKE_SYSTEM_NAME=Windows` makes `WIN32` true, `GLFW_BUILD_WIN32` stays ON, and
the Win32 sources need only `<windows.h>`, which mingw-w64 has. The native row
is right too: `UNIX` is true there so both backends would default ON and
`find_package(X11 REQUIRED)` would fire — the recipe turning them off is what
makes that row work, exactly as stage1:144 says.

## The honest limitation, correctly stated

The library builds, but it is GLFW's **null** backend: at runtime a consumer
must call `glfwInitHint(GLFW_PLATFORM, GLFW_PLATFORM_NULL)` or
`_glfwSelectPlatform` errors out. The recipe's comment says this plainly
("the installed library creates no real window"), and that is the right call —
it is upstream's own documented switch, not a workaround, and a reviewer who
expects a display server here is wrong. stage1.md:149-154 states it again as
the thing to scrutinise. Good.

## Verdict

ACCEPT. The central claim survived the strongest test available short of a
build: I compiled the entire implied source set at the lowest API level and it
is clean. Every option exists, the recipe is system-neutral and uses
`$CMAKE_FLAGS` throughout, no host program or target binary is executed, and
the null-backend limitation is documented rather than glossed. The one
inaccuracy (the `THREADS_PREFER_PTHREAD_FLAG` claim on the two non-Bionic rows)
does not affect the recipe and is recorded here for the record.
