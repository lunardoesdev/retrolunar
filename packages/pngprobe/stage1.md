# pngprobe build forecast

- Recipe: `generic.lua` — **there is no `source.lua`.** The recipe is
  self-contained: it writes its own `Cargo.toml` and `src/main.rs` with
  `cat` heredocs, declares `version = "0.1.0"` and `libpng_sys = "1.1.11"` as
  recipe fields, and `require()`s its dependencies directly. This makes it the
  only package in the shard built by cargo.
- Build system: **cargo**, via a generated Rust crate.
- Installs: `bin/pngprobe`, a target executable. It is deliberately a
  *probe*: three lines of Rust that print the libpng version and assert it is
  at least 1.6.48.
- Requires: `freetype` (exists), `libpng` (exists). Note **`freetype` is
  required but never used** by the generated code — the probe only calls
  `png_access_version_number`. See risk 2.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | cargo is the build tool, configured per system: the Android systems export `CARGO_BUILD_TARGET`, `CARGO_TARGET_<triple>_LINKER`, `_AR`, `RUSTFLAGS="-L $PREFIX/lib"` and the `CC_/CFLAGS_/CXX_/CXXFLAGS_` cc-crate vars (`aarch64-android24/generic.lua:139-152`). `PNG_CONFIG="false"` at `:25` is the load-bearing switch: it stops `libpng-sys`'s build script from trying to *run* a test program to discover libpng's configuration — which would be executing a target binary, forbidden here, and would fail anyway since nothing can run an aarch64 binary on this host. The recipe then statically verifies the link instead (`:28-34`). |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; the recipe's `[ -f "$_bin" ] || _bin="$_bin.exe"` at `:22` handles the `.exe` suffix, so someone already thought about it. |
| clang-native | WILL BUILD | As above; `CARGO_BUILD_TARGET` is set for native too in this tree's systems, and the host toolchain links natively. |

**API level notes.** None. The probe links libpng and calls one function that
returns a compile-time constant. No API-gated symbol. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The static link verification at `:28-33` is the best-designed thing in
   this shard and should be the model.** Because the probe cannot be *run*, the
   recipe instead inspects the result: it runs `$OBJDUMP -p "$_bin"`, greps for
   `libpng16`, and on failure dumps the whole objdump output to stderr and
   exits 1. So a build that produced a binary not actually linked against this
   tree's libpng **fails loudly** instead of publishing a useless probe. That is
   a host-side static check doing the job an execution check would do, which is
   precisely what AGENTS.md:380-384 prescribes.
2. **`require("freetype")` at `:1` is unused.** The generated Rust calls only
   `libpng_sys::ffi::png_access_version_number()`. FreType is a libpng
   dependency, so requiring it is defensible as "make sure libpng's
   dependencies are present" — but nothing in the recipe or the generated code
   references it, and it costs a rebuild of the whole chain when it changes.
   Worth a comment or removal.
3. **The hardcoded `assert!(ver >= 10648, …)` at `:22` encodes libpng 1.6.48 as
   an integer.** That duplicates the version pinned in `libpng/source.lua` and
   in the `libpng_sys = "=1.1.11"` requirement. Three places to keep in sync
   when libpng is updated — the same duplication trap as lua's hand-written
   `.pc` and mpc/mpfr's `--docdir`.
4. **`libpng_sys = "=1.1.11"` is a crates.io version, not the C library
   version.** The two are related but not identical, and `PNG_CONFIG="false"` is
   what stops the crate's build script from trying to reconcile them by running
   `pkg-config`. Worth a reviewer confirming the pinned crate still matches
   libpng 1.6.48's ABI expectations, since the crate's build script is bypassed
   entirely.
5. **cargo is a host tool with no `require()`.** Correct — it runs on the build
   machine, and the systems configure it through environment variables. The
   same reasoning as `meson`.
6. **This is a test harness, not a library.** Nothing in the tree depends on
   `pngprobe`; it exists to prove that a consumer can link this tree's libpng.
   A green run is the verification `topackage.md`'s libpng entry currently
   lacks — and **that is worth pointing out: `libpng` has no `[x]` entry, and
   `pngprobe` is the mechanism that would generate the evidence for one.**
7. `cargo build --release` at `:25` is not serialised, but cargo has no simple
   `--jobs 1` equivalent that the tree uses elsewhere, so this is acceptable.

**How to verify once built.**

- `bin/pngprobe` exists.
- **`$OBJDUMP -p bin/pngprobe | grep libpng16` must succeed** — the recipe
  already enforces this, so reaching a successful publish means it held. This
  is the primary check, and it is stronger evidence than a mere file-presence
  test.
- `file bin/pngprobe` reports the target machine; on Android,
  `ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c`.
- `llvm-nm -u bin/pngprobe | grep -cw png_access_version_number` must be
  **non-zero** (undefined against libpng) — the direct symbol-level confirmation
  that the probe really links libpng rather than having inlined a constant.
- **Do not run `bin/pngprobe`.** The whole design is that it cannot be run.
