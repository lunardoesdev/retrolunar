# spdlog build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.15.3 (`github.com/gabime/spdlog/archive/refs/tags/v1.15.3.tar.gz`)
- Build system: **CMake** (`generic.lua:11`)
- Installs: `lib/libspdlog.a`, `include/spdlog/*.h`, `lib/pkgconfig/spdlog.pc`,
  plus a CMake package config
- Requires: `fmt` (`generic.lua:1`, **exists** in `packages/fmt`) and
  `spdlog@source` (`generic.lua:2`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The one dependency is `fmt`, and `-DSPDLOG_FMT_EXTERNAL=ON` (`generic.lua:11`) is what consumes it: it makes `spdlog` include `<fmt/*>` instead of its bundled `bundled/fmt-include/`. That works because `$CMAKE_PREFIX_PATH=$PREFIX` is in `$CMAKE_FLAGS` (`packages/aarch64-android21/generic.lua:114`) and fmt installs `include/fmt/*.h` plus `lib/libfmt.a`. spdlog's library target is otherwise header-only in the sense that it compiles one TU (`src/spdlog.cpp`) which is STL-only: `<string>`, `<vector>`, `<cstdio>`. No Bionic gap. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. `SPDLOG_BUILD_EXAMPLE=OFF` and `SPDLOG_BUILD_BENCH=OFF` keep the two host programs out. |
| clang-native | WILL BUILD | Native; same flags. |

**API level notes.** **No new wall.** Neither spdlog's compiled source nor
fmt's uses anything beyond the C++ standard library plus `<cstdio>`/`<ctime>`
for the `stdout_color_mt` sink. `localtime`/`strftime` — which spdlog's
`fmt` bundled backend uses for timestamps — are in Bionic at API 21. The
`-lm` in `$LDFLAGS` covers any libm residue. The API level is inert.

**Risks / what a reviewer should check.**
1. **`-DSPDLOG_FMT_EXTERNAL=ON` is a real dependency, not a preference.** With
   it off (the upstream default), spdlog compiles its *vendored* fmt from
   `bundled/`, giving the prefix two independent copies of the same formatting
   engine and two copies of `fmt::format` symbols. The recipe comment at
   `generic.lua:9-10` states the intent ("one formatting engine in the whole
   tree") and that is a good reason. But note the consequence: **the resulting
   `libspdlog.a` has an undefined reference to `fmt::format`**, so a consumer
   must link `-lfmt` too. `spdlog.pc` handles this with `Requires: fmt` when
   `SPDLOG_FMT_EXTERNAL` is on — verify that field is present after install,
   because a `spdlog.pc` with a missing `Requires` would fail at consumer link
   time, not here.
2. **`SPDLOG_INSTALL=ON` is upstream's default**, so like snappy's test flag
   this is documentation rather than a fix. `-DBUILD_SHARED_LIBS=OFF` is the
   load-bearing one.
3. **Dependency-order fragility.** `require("fmt")` is at `generic.lua:1`,
   before `require("spdlog@source")` at `:2`. The loader appends to the queue
   in call order, so `fmt` builds first. That is correct as written; a future
   edit that moves the `fmt` require below the `@source` require would be fine
   too (sources never build), but moving it *after* nothing would not.
4. No `-std=` is pinned. spdlog 1.15.3 requires C++11 at minimum and its
   CMake sets `target_compile_features(spdlog PUBLIC cxx_std_11)`; all six
   `$CXX` defaults satisfy that, so no language flag is hardcoded. Correct.

**How to verify once built.**
- `lib/libspdlog.a`, `include/spdlog/spdlog.h`, `include/spdlog/fmt/fmt.h`
  (the external-fmt forwarding header), `lib/pkgconfig/spdlog.pc`
- `pkg-config --modversion spdlog` → 1.15.3
- `pkg-config --print-requires spdlog` → `fmt` (this is the check that proves
  the external-fmt wiring survived)
- `llvm-objdump -f lib/libspdlog.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm -u lib/libspdlog.a | grep -c 'fmt'` — a **non-zero** count is
  correct here and is the expected consequence of `SPDLOG_FMT_EXTERNAL=ON`;
  zero would mean fmt got statically absorbed
- `find $PREFIX/include/spdlog -name 'bundled'` must be **empty**: a vendored
  `fmt/` directory would mean the external switch did not take