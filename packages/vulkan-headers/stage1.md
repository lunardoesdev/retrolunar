# vulkan-headers build forecast

- Recipe: `generic.lua`, source `source.lua` (no `android.lua`)
- Version pinned: 1.4.364 (tag `v1.4.364`, `KhronosGroup/Vulkan-Headers`)
- Build system: CMake 3.22.1 minimum (`CMakeLists.txt:8`)
- Header-only: **yes.** `add_library(Vulkan-Headers INTERFACE)` (`CMakeLists.txt:52`)
- Installs: `include/vulkan/` (`:97`), `include/vk_video/` (`:96`),
  `share/vulkan/registry/` (`:99`), `share/cmake/VulkanHeaders/` (`:112-124`).
  **No library file. No `.pc` file** — upstream ships neither.
- Requires: `vulkan-headers@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled: the only library target is `INTERFACE` (`CMakeLists.txt:52`), and `VULKAN_HEADERS_ENABLE_TESTS=OFF` keeps `add_subdirectory(tests)` (`:79-82`) out of the graph. `VULKAN_HEADERS_ENABLE_MODULE=OFF` keeps the C++23 OBJECT library (`:56-77`) out. The remaining commands are `file(READ)`, `write_basic_package_version_file` and four `install` calls. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; no MSVC-only path is taken, and an `INTERFACE` export set carries no compiler-detected content. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is a file copy, identical on every
system, and no architecture check applies. `armv7a-*` and `i686-*` match the
`aarch64-*` rows for the same reason.

## The layout is the deliverable, and upstream lays it out — not us

This is the Eigen trap the brief warned about, and Vulkan-Headers has a
*second* twist on it. `install(DIRECTORY include/vulkan DESTINATION
${CMAKE_INSTALL_INCLUDEDIR})` at `:97` is recursive, so the whole header
directory lands; but `include/vk_video` is a **separate sibling directory**
installed by its own `install(DIRECTORY)` at `:96`. A recipe that copied
`include/` wholesale would get both, but a recipe that copied only
`include/vulkan` — the obvious guess from the top-level listing — would
silently lose all twelve `vulkan_video_codec_*.h` files.

The third directory is the one that is easy to miss entirely: `:99` installs
the **registry** (`registry/vk.xml`, 3.3 MB, plus the Python generator
scripts) to `${CMAKE_INSTALL_DATADIR}/vulkan`, i.e. `share/vulkan/registry/`,
**not** under `include/`. That is upstream's documented layout and it is what
the recipe gets, because the recipe runs upstream's own install rules rather
than assembling a file list.

**There is no generated version header.** The brief expected one. There is
not: `vlk_get_header_version()` (`CMakeLists.txt:17-39`) *reads*
`VK_HEADER_VERSION` out of the shipped `include/vulkan/vulkan_core.h`
(`:64` → `364`) to compute `project(... VERSION ...)`, and nothing in the file
writes a header back. The tree is installed verbatim.

## Risks / what a reviewer should check

1. **`VULKAN_HEADERS_ENABLE_MODULE` has a host-dependent default and is
   pinned OFF.** `CMakeLists.txt:47` is a `cmake_dependent_option` whose
   default is `ON` when `23 IN_LIST CMAKE_CXX_COMPILER_IMPORT_STD`. I probed
   that variable on the host cmake 4.4.3 + clang and it is empty, so the
   default would happen to be OFF — but a different host cmake/compiler pair
   could set it, and the recipe must not inherit that. With it ON, `:56-77`
   builds `Vulkan-HppModule` as an `OBJECT` library from `vulkan.cppm` /
   `vulkan_video.cppm` with `cxx_std_23` and `CXX_MODULE_STD ON`.
2. **The test block runs target binaries.** `tests/CMakeLists.txt` is three
   `add_test()` calls (`:10`, `:20`, `:25`) that shell out to
   `ctest --build-and-test` and `cmake --install`. On a cross build the
   `--build-and-test` step *executes* the binary it just built. `OFF` is
   mandatory, not tidiness.
3. **`project(VULKAN_HEADERS LANGUAGES C CXX)` (`:42`) enables the C++
   compiler** even though nothing is compiled. Harmless, but it means a
   configure-time compiler check happens for both languages.
4. **The `PATTERN "*.cppm" EXCLUDE` on `:96`/`:97` is conditional** (`:90-94`).
   With MODULE off, `CPPM_PATTERN` is the empty string and the two
   `vulkan*.cppm` files are installed as ordinary headers. That is upstream's
   intent, and the recipe reproduces it by not second-guessing the flag.
5. **Size.** `registry/` is 19 MB and `include/` 22 MB unpacked, so this
   installs ~40 MB per system prefix. That is upstream's layout, not a recipe
   choice, but it is worth recording before someone wonders.

## How to verify once built

- `include/vulkan/vulkan.h`, `include/vulkan/vulkan_core.h` and
  `include/vulkan/vulkan.hpp` exist.
- **`include/vk_video/vulkan_video_codec_h264std_decode.h` exists.** This is
  the check that catches the layout mistake; `include/vulkan/` alone does not.
- `share/vulkan/registry/vk.xml` exists and `share/vulkan/registry` is *not*
  empty — the `:99` install is the one a hand-written file list drops.
- `share/cmake/VulkanHeaders/VulkanHeadersConfig.cmake` and
  `VulkanHeadersConfigVersion.cmake` exist (`:112-124`).
- **`find $OUT -name '*.a' -o -name '*.so'` returns nothing** — the single
  check that proves nothing was compiled.
- `find $OUT -name '*.pc'` returns nothing. Expected, not a gap.
- Compare two systems' `include/` with `diff -r`: any difference is a bug.
