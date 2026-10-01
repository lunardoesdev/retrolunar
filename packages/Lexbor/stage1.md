# Lexbor build forecast

- **Package:** Lexbor (recipe and directory use upstream's capitalisation;
  `topackage.md` lists it that way, and the tree has no other capitalised
  package to set a precedent against)
- **Version:** 3.0.0 (release `v3.0.0`, 2026-03-31, newest on lexbor/lexbor)
- **Upstream URL:** `https://github.com/lexbor/lexbor/archive/refs/tags/v3.0.0.tar.gz`
  (HTTP 200, 5 777 325 bytes, top directory `lexbor-3.0.0/`)
  The release list has **no assets**, so the git tag archive is the only form.
- **Build system: cmake.** No autotools in the tree.
- **Config template: none.** No `AC_CONFIG_HEADERS`, no `config.h.in`. lexbor
  generates `lexbor_config.c` and headers from templates in its build tree.
  **No timestamp guard applies and none is written.**
- **Dependencies required: none.** No `require()` of any other package.
- **Upstream ships both a `.pc` file and a CMake package config** —
  `lexbor.pc.in` and `lexbor-config.cmake.in` are both in the tarball.
- **Installs:** `lib/liblexbor_static.a`, `lib/pkgconfig/lexbor.pc`,
  `lib/cmake/lexbor/lexbor-config.cmake` + version + targets, and the headers
  **under their module subdirectories**:
  `include/lexbor/{core,css,dom,encoding,engine,html,ns,punycode,selectors,style,tag,unicode,url,utils}/*.h`.
  **There is no `include/lexbor.h`.** The only rule that installs headers is
  `INSTALL_MODULE_HEADERS` in `config.cmake`, which does
  `install(DIRECTORY source/lexbor/<module> DESTINATION include/lexbor
  FILES_MATCHING PATTERN "*.h")`; `install(DIRECTORY)` reproduces the module
  directory, so a module's headers land *inside* `include/lexbor/<module>/`.
  The umbrella header is therefore `include/lexbor/core/lexbor.h` — `find . -name
  lexbor.h` over the tree returns exactly one hit,
  `source/lexbor/core/lexbor.h` — and the HTML umbrella is
  `include/lexbor/html/html.h`. My first draft listed flat
  `include/lexbor.h` and `include/lexbor/**`, which do not match what installs.

### What actually gets built, from the CMakeLists

Lexbor is unusual: it builds one **shaded** library containing every module,
or one library per module, depending on `LEXBOR_BUILD_SEPARATELY`. Read from
`CMakeLists.txt`:

- `:52` `LEXBOR_BUILD_SHARED` default **ON**; `:53` `LEXBOR_BUILD_STATIC`
  default **ON**. With both on, `CMakeLists.txt:204-208` and `:211-221` create
  `liblexbor` (SHARED) and `liblexbor_static` (STATIC) from one
  `${LEXBOR_SOURCES}` list, and `:240-248` hands each to `ADD_MODULE_LIBRARY`.
- `:95-96` — the targets are named `liblexbor` and `liblexbor_static`.
- `:435-441` — `lexbor.pc` is generated from `lexbor.pc.in`, whose
  `Libs:` line is `-l@PROJECT_NAME@`, i.e. **`-llexbor`**. **With
  `LEXBOR_BUILD_SHARED=OFF` the `.pc` will name a library that is not built.**
  See risk 1.
- `:225-231` (shared, not separately) and `:278-281` (static) install the
  headers via `INSTALL_MODULE_HEADERS`.
- `:402-437` install the CMake package config and the `.pc`.

Everything else is already off upstream and is the host-program gate:

| option | line | default |
| --- | --- | --- |
| `LEXBOR_BUILD_EXAMPLES` | :53 | **OFF** |
| `LEXBOR_BUILD_TESTS` | :54 | **OFF** |
| `LEXBOR_BUILD_TESTS_CPP` | :55 | OFF |
| `LEXBOR_BUILD_UTILS` | :58 | OFF |
| `LEXBOR_BUILD_BENCHMARKS` | :57 | OFF |
| `LEXBOR_BUILD_FUZZER` | :59 | OFF |
| `LEXBOR_BUILD_WASM` | :51 | OFF |
| `LEXBOR_INSTALL_HEADERS` | :65 | **ON** |
| `LEXBOR_WITHOUT_THREADS` | :51 | ON ("Not used now, for the future", `:8`) |

Those are exactly the seven `add_subdirectory` calls at `:367,375,382,389,396`
plus the fuzz one — so with the defaults, **no host program is compiled**.

**Threads: there are none.** The `LEXBOR_WITHOUT_THREADS` option is declared at
`:51` but upstream's own comment at `:8` says "Not used now, for the future",
and grepping every source file under `source/lexbor/` (523 files) for
`pthread` returns **zero hits**. So there is no thread library to resolve and
no `-lpthread` on Bionic (which has no separate one) to worry about.

**Parallelism / memory: does it need a parallel build? No.**
`cmake --build build --parallel 1` is the only build invocation, and lexbor has
no build-script construct that requires or assumes parallelism — no
custom command with `nproc`, no generated unity build. Lexbor *is* a large
library (523 source files, dominated by the `lexbor/html/interfaces/` set of
~110 tiny files), so the build is **slow**, but it is not memory-hungry: peak
memory stays far under the 2 GB rule, since each translation unit is small.

**API level notes.** **No new wall.** lexbor is an HTML/CSS parser whose
platform surface is stdio plus the `malloc` family. It performs its own Unicode
normalisation and IDNA in `lexbor/unicode/` rather than calling into libc's
locale or `iconv`, so the API-26 (`nl_langinfo`) and API-28 (`iconv.h`)
boundaries do not come into play. It does not use `mktime_z` (API 35).
**The API level is inert** — 21, 24 and 35 take an identical path.

**Risks / what a reviewer should check.**
1. **The `.pc` names `-llexbor`, but the static archive is
   `liblexbor_static.a` — and the recipe now rewrites it.** `lexbor.pc.in`'s
   `Libs:` line is `-l@PROJECT_NAME@` with `PROJECT_NAME` = `lexbor`
   (`CMakeLists.txt:193`), so the installed file emits `-llexbor` and every
   pkg-config consumer fails to link. My first draft called this unfixable
   ("AGENTS.md forbids patching, so the recipe cannot fix it") **and that was
   wrong** — it is a misreading of the rule. **AGENTS.md:238-254 explicitly
   permits rewriting a *generated* artifact under `$OUT` with `awk` plus `cp`,
   and names `packages/glog/generic.lua:68-69` as the worked example.** The
   no-patch rule covers files that came *out of* the upstream tree; a `.pc`
   that `cmake --install` just wrote into `$OUT` is our own build output, and
   the loader already rewrites that same file for `$OUT`→`$PREFIX`
   (`src/loader.lua:454-468`). The recipe now runs, after `cmake --install`:

   ```sh
   awk '{ if ($0 ~ /^Libs:/) print "Libs: -L${libdir} -llexbor_static"; else print }' \
       "$OUT/lib/pkgconfig/lexbor.pc" > "$WORK/lexbor.pc"
   cp "$WORK/lexbor.pc" "$OUT/lib/pkgconfig/lexbor.pc"
   ```

   The whole line is replaced rather than appended, and `-L${libdir}` is kept,
   because pkg-config resolves a repeated key **last-key-wins** — an appended
   second `Libs:` would drop the `-L` instead of adding to it, which is the
   trap `packages/glog/generic.lua:59-61` records. The substitute contains no
   `$OUT`, so the loader's staged-`.pc` pass prints it verbatim, and the
   rewrite cannot double-apply because `cmake --install` regenerates the `.pc`
   from `lexbor.pc.in` on every build. **Verify with
   `pkg-config --libs lexbor` → `-L… -llexbor_static`.**
2. **`LEXBOR_INSTALL_HEADERS` stays ON** (default ON, `:65`) — it is what
   installs `lexbor.h` and the whole `lexbor/` tree via
   `INSTALL_MODULE_HEADERS`. Without it a header-only consumer gets nothing.
3. **`LEXBOR_BUILD_SEPARATELY=OFF`** (default) is left alone deliberately: it
   is what produces one shaded `liblexbor`/`liblexbor_static` rather than
   ~15 per-module libraries, which is the smaller and simpler install.
4. **`LEXBOR_BUILD_SHARED=OFF` is the only flag passed**, deliberately. The
   other seven gates are already OFF upstream (table above), and restating them
   would be redundant flags that drift the moment upstream changes a default.
5. **`cmake_minimum_required(VERSION 2.8.12...3.27)`** is the oldest minimum in
   this assignment, and it uses the range syntax. The systems' cmake 4.4.3 is
   inside the upper bound. The `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` in
   `$CMAKE_FLAGS` is what makes the 2.8.12 floor acceptable to cmake 4.x; that
   flag is present in every system recipe, so this package relies on it exactly
   as `packages/rapidjson` does.
6. **The build is long.** 523 source files, serially. Not a resource risk, but
   the builder should expect this to be the slowest recipe in the batch and not
   treat a quiet log as a hang.

**How to verify once built.**
- `lib/liblexbor_static.a`, `include/lexbor/core/lexbor.h`,
  `include/lexbor/html/html.h`, `lib/pkgconfig/lexbor.pc`,
  `lib/cmake/lexbor/lexbor-config.cmake`
- `llvm-objdump -f lib/liblexbor_static.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/liblexbor_static.a | grep -c lxb_html_document_parse`
  → non-zero, proving the shaded build really contains the HTML module
- `llvm-nm -u lib/liblexbor_static.a | grep -cE 'pthread_|socket|connect'` → **0**,
  which is the check for the "no threads, no sockets" claim in the mingw row
- **Risk 1 check (the `.pc` fix):** `pkg-config --libs lexbor` must print
  `-L<prefix>/lib -llexbor_static`. Before the rewrite it printed `-llexbor`,
  naming a file that is not in the prefix. Cross-check that the named archive
  exists with a glob-free pairing:
  `test -f "$PREFIX/lib/$(pkg-config --libs lexbor | sed 's/.*-l//').a"` —
  this cannot report a phantom failure the way a hardcoded
  `lib/liblexbor.so` would.
- **Headers landed under the module subdirectories:**
  `test -f "$PREFIX/include/lexbor/core/lexbor.h" && test -f
  "$PREFIX/include/lexbor/html/html.h"`. **Do not look for
  `include/lexbor.h`** — it does not exist and its absence is not a failure.
- **No shared object:** `find "$PREFIX/lib" -maxdepth 1 -name 'liblexbor.so*' | wc -l`
  → `0`. Scoped to lexbor's own name so a second package in `$PREFIX` cannot
  perturb it.
- **lexbor contributes no `bin/` entry.** Stated as a fact about this package
  rather than checked with a `find` over `$PREFIX/bin`, which is the whole
  prefix's `bin/` and would fail as soon as any other package installs a
  binary — the unscoped-check trap AGENTS.md:558-567 names.
- Rerun should print `skip Lexbor (fresh)`.