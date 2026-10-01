# imgui 1.92.9 — stage 1 build forecast

**Package:** imgui
**Version:** 1.92.9 (upstream calls itself "Dear ImGui"; `IMGUI_VERSION` is
`"1.92.9"` at `imgui.h:32`)
**Upstream:** https://github.com/ocornut/imgui
**Build system:** **none.** No `CMakeLists.txt`, no `Makefile`, no `configure`
anywhere in the tree — verified below.

A forecast from reading upstream source. Nothing has been compiled.

## The shape, and what does and does not compile

Dear ImGui is a library you either drop into your own build or archive
yourself. The core is four translation units:

| File | Lines | Role |
| --- | --- | --- |
| `imgui.cpp` | 18 626 | core + platform + default backend glue |
| `imgui_draw.cpp` | — | the renderer (embeds stb_truetype and stb_rect_pack) |
| `imgui_tables.cpp` | — | tables |
| `imgui_widgets.cpp` | — | widgets |

Plus six headers: `imgui.h`, `imgui_internal.h`, `imconfig.h`,
`imstb_rectpack.h`, `imstb_textedit.h`, `imstb_truetype.h`.

**Compiles:** those four `.cpp` files, with nothing else.

**Does not compile, deliberately:**

- `imgui_demo.cpp` — example code (the ImGui demo window), not library.
- `backends/` — 19 files, one per windowing/rendering API
  (`imgui_impl_glfw.cpp`, `imgui_impl_sdl2.cpp`, `imgui_impl_dx11.cpp`,
  `imgui_impl_metal.mm`, `imgui_impl_android.cpp`, …). Each needs a windowing
  or rendering library that this prefix does not provide. `imgui_impl_glfw.cpp`
  would pair with the `glfw` package, but only a consumer that actually has a
  window system can use it — the same "no display server" wall `glfw`'s own
  forecast records.
- `examples/` — 30 host programs, and most of them need GLFW + OpenGL anyway.
- `misc/freetype/` — optional, behind `IMGUI_ENABLE_FREETYPE`, which nothing
  here defines; it would also need FreeType and a font rasteriser.
- `misc/cpp/` — `imgui_stdlib.*`, optional extra widgets.

**A trap worth naming.** `imgui.cpp:2338-2342` includes `"stb_sprintf.h"`,
and `misc/cpp/` does *not* contain that file (I listed `misc/` — it holds only
`README.txt`, `cpp/`, `debuggers/`, `fonts/`, `freetype/`, `single_file/`). The
include is guarded by `#ifdef IMGUI_USE_STB_SPRINTF` (`imgui.cpp:2334`), which
is **not** defined by default, so it never fires. If a future consumer enables
it, the build fails on a file this tree does not ship. `imgui_draw.cpp` has the
same shape at `:133-137` and `:158-162`, but its defaults —
`imstb_rectpack.h` and `imstb_truetype.h` — *are* present in the tree, so those
are fine.

## What it needs from a host

Essentially nothing. The complete set of system headers the four core sources
include is:

| File:line | Header |
| --- | --- |
| `imgui.cpp:1257` | `<stdio.h>` |
| `imgui.cpp:1258` | `<stdint.h>` |
| `imgui.cpp:1260` | `<time.h>` |
| `imgui_draw.cpp:205`, `imgui_tables.cpp:48`, `imgui_widgets.cpp:43` | `<stdint.h>` |

Everything else is either a Dear ImGui header or a platform header behind a
guard that cannot fire here:

- `imgui.cpp:1283-1285` `<Windows.h>`, `:1287` `<windows.h>` — under
  `#if defined(_WIN32)`. Fires on mingw, where the MinGW-w64 SDK provides it.
- `imgui.cpp:1297` `<TargetConditionals.h>`, `:16215` `<Carbon/Carbon.h>` —
  under `__APPLE__`.
- `imgui.cpp:16350` `<imm.h>` — under `_MSC_VER`.
- `imgui.cpp:16303` `<shellapi.h>`, `:16316-16317` `<sys/wait.h>`/`<unistd.h>` —
  Windows and POSIX shell-open paths.
- `imgui_draw.cpp:40` `misc/freetype/imgui_freetype.h` — under
  `IMGUI_ENABLE_FREETYPE`.
- `imgui_draw.cpp:4126` `../stb/stb_image_write.h` — under `IMGUI_ENABLE_STB_IMAGE_WRITE`.

**The only platform call in the core is `localtime_r()`** (`imgui.cpp:4490`,
used by `ImGui::GetPlatformIO().FontGlobalScale` session timing via
`time()`/`localtime_r()` at `imgui.cpp:1260`). Bionic has `localtime_r` at
every API level. On Windows, `imgui.cpp:1261-1263` provides its own
`localtime_r` shim over `localtime_s`, so it is not a dependency there either.

No `<dlfcn.h>`, no `<pthread.h>`, no `<locale.h>`/`iconv`, no X11, no GL, no
GPU driver.

## API-level gating

I grepped all four core sources for every documented wall — `process_vm_readv`,
`posix_spawn`, `mblen`, `getpass`, `O_BINARY`, `POSIX_MADV_*`, `mktime_z`,
`nl_langinfo`, `iconv`, `scandir`, `getline` — and there are **zero hits**.
`nl_langinfo` in particular is not used, so API 26's introduction of it is
irrelevant; `mktime_z` (API 35) is not used either. The API level is not a
variable for this package.

## What it installs

- `lib/libimgui.a` — built by the recipe with `$CXX`/`$AR`/`$RANLIB`, the same
  shape `packages/lua/generic.lua` uses for the same reason (upstream makefile
  is host-only).
- `include/{imgui.h,imgui_internal.h,imconfig.h,imstb_rectpack.h,
  imstb_textedit.h,imstb_truetype.h}` + `LICENSE.txt`.
- `lib/pkgconfig/imgui.pc` — hand-written; upstream ships no `.pc` and no CMake
  package config.

**No `android.lua`.** Dear ImGui has no Android-specific build switch at all;
`backends/imgui_impl_android.cpp` is the only Android-aware file and it is
platform glue a consumer compiles against its own Android NDK app, not part of
the library.

## Dependencies

**None.** No `require()` other than `imgui@source`, and no external header,
library or host program.

## Source

`https://github.com/ocornut/imgui/archive/refs/tags/v1.92.9.tar.gz` — verified
HTTP 200, 2 123 328 bytes, and `tar tzf` lists 281 files which matches the
281 files extracted. Single top-level directory `imgui-1.92.9`, stripped by the
recipe. Dear ImGui publishes no release assets and has no build system in-tree;
it releases by tagging.

**On the `-docking` tags:** the repo also carries `v1.92.9b`,
`v1.92.9b-docking` and `v1.92.9-docking`. Those are a parallel line of
development, not a newer master release, and the docking branch adds an
`imgui_internal` layout that differs. This recipe pins the plain `v1.92.9`
master tag. A reviewer who wants the docking branch should say so explicitly
rather than have the recipe drift onto it.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | Four `.cpp` files whose entire external include set is `<stdio.h>`, `<stdint.h>`, `<time.h>`, plus `localtime_r` — all present at API 21. No API-gated symbol (see above). Nothing is architecture- or version-conditional. |
| `aarch64-android24` | WILL BUILD | As above. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above; the core has no SIMD and no x86-specific code path. |
| `x86_64-mingw` | WILL BUILD | As above, plus `<windows.h>` (`imgui.cpp:1283-1285`) and the `localtime_s` shim (`imgui.cpp:1261-1263`), both provided by mingw-w64. The Win32 clipboard and IME paths are enabled by default for non-MSVC compilers unless `IMGUI_DISABLE_WIN32_DEFAULT_*_FUNCTIONS` is set (`imgui.cpp:1266-1290`); they are declared in `<windows.h>` and do not need a link-time library at *compile* time. |
| `clang-native` | WILL BUILD | Same source set as the Android rows; only the `_WIN32`/`__APPLE__` guards differ, and neither fires. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.

## What a reviewer should scrutinise

1. **C++ dialect is the compiler default.** Dear ImGui states C++11 as its
   floor in `docs/compile.md`. The NDK wrappers and mingw's g++ both default
   well above that, and I found nothing in the four sources that a later
   standard removes. But this package does not pin a dialect, so this is the
   thing a real build would confirm first.
2. **The archive name is `libimgui.a` and it contains only the core.** Many
   distributions also ship `libimgui.a` *with* `imgui_demo.cpp` folded in, and
   some ship a separate `libimgui_demo.a`. This recipe does neither. If a
   consumer expects the demo, they compile `imgui_demo.cpp` themselves — it is
   in the source tree and needs nothing but the installed headers.
3. **No `.pc` and no CMake config from upstream**, so the `imgui.pc` is ours.
   `Libs: -L${libdir} -limgui` with no other dependencies is accurate: the
   archive has no unresolved external beyond libc.
4. **`backends/` is excluded wholesale.** That is the decision most worth a
   reviewer's opinion, because it is the one place where "build the library"
   and "build something usable" diverge. The recipe's comment says
   `imgui_impl_glfw.cpp` pairs with the `glfw` package — a consumer can build
   it against both, but nothing here can prove it, since `glfw` itself builds
   only its null backend on these targets.