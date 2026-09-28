# AGENTS.md — retrolunar package manager

This file is for coding agents working in this repo. It describes how the
package manager works and how to add or fix packages and systems.

## What this is

`retrolunar` is a tiny C binary with an embedded Lua 5.5 interpreter
(`src/main.c`, Lua sources in `lua-5.5.1/`). At startup it runs the Lua
loader (`src/loader.lua`, embedded into the binary via `src/embed.py` +
meson `custom_target`). The loader overrides global `require` and the
`install` subcommand prints a POSIX shell script that builds everything.

Typical flow:

```sh
./builddir/retrolunar install --nest ./nest --packages ./packages 'pngprobe@aarch64-android24' > build.sh
sh -n build.sh
ANDROID_HOME=/path/to/sdk sh build.sh
```

## Layout

- `packages/<name>/source.lua` — fetch recipe: downloads and unpacks
  upstream sources, copies the tree to `$OUT/<name>/`. Runs under the
  `source` pseudo-system, lands in `$NESTDIR/source/<name>/`.
- `packages/<name>/generic.lua` — fallback build recipe when the package has
  no recipe for the requested system. It runs for that requested system; it
  is not a separate target system.
- `packages/<sys>/generic.lua` — system description: a `system({setup=...})`
  call whose `setup` shell fragment defines the whole toolchain
  environment. Systems live in the same `packages/` tree as packages.
- `packages/<sys>/*.cmake`, `*.ini` — cmake toolchain / meson cross files
  shipped next to the system recipe, referenced via `$SYSDIR`.
- `./nest` — build output (gitignored). `$NESTDIR/<sys>/` is the install
  prefix per system, `$NESTDIR/source/<name>/` holds unpacked sources,
  `$NESTDIR/tmp/` holds per-package `WORK`/`OUT` stage dirs.

## The loader (`src/loader.lua`)

Three `require` forms:

- `require("pack@sys")` — exact: `packages/pack/sys.lua`, else
  `packages/pack/generic.lua`, else error. Runs the chunk with `SYSTEM=sys`.
- `require("pack")` — bare: inherits the requiring module's system from an
  explicit stack (`sys_stack`); at top level uses the C default
  (`DEFAULT_SYSTEM`, `"clang-native"`, overridable with
  `-DRETROLUNAR_DEFAULT_SYSTEM=...`). Inside a system file (stack top is
  `generic`) bare requires also fall back to the C default. Exact
  `pack@sys` never consults the stack.
- `require("./x")`, `require("../x")` — relative to the requiring file's
  directory, then `RETROLUNAR_LIB` (default `.`). `a.b` maps to `a/b`.

`recipe(t)` attaches `file`, `dir`, `sys`, and the real `system` table
(loaded on demand as `sys@generic`), then appends `t` to the build queue.
Queue order is dependency order for free: `require` calls run before the
trailing `recipe()` call, so leaves land first; duplicates by canonical
key (`pack@sys`) are an error. `require_queue()` returns a snapshot,
`require_script(nestdir, pkgdir)` emits the install script,
`require_system()` returns the current system. `system(t)` attaches
`file`/`dir` and returns the table.

Recipe fields (`version`, `git`, `tag`, plain strings) become shell
variables in the generated block, so `$version` etc. work in build bodies.
Reserved keys (`build`, `file`, `dir`, `sys`, `system`, `name`) are skipped.

## The generated script

Per queued package, one `if fresh ... else ... fi` block:

- Freshness: stamp `$NESTDIR/<sys>/.retrolunar-<name>` newer than the
  recipe file, the system file, and the system dir. Stale by any single
  `-nt` comparison means rebuild; missing stamp means build.
- Block prologue: system `setup` fragment, then
  `WORK=$(mktemp -d ...)` + `OUT=$(mktemp -d ...)` under `$NESTDIR/tmp`,
  `trap 'rm -rf "$WORK" "$OUT"' EXIT`, `cd "$WORK"`,
  `PREFIX="$NESTDIR/<sys>"`, `RECIPEDIR="$PACKAGEDIR/<name>"`,
  `SYSDIR` pointing at the system dir, all exported with
  `PACKAGEDIR NESTDIR RECIPEDIR OUT PREFIX SYSDIR`.
- Build body verbatim (heredoc `EOF` terminators normalized to column 0).
- Staged `.pc` files get `$OUT` paths rewritten to `$PREFIX` via
  `while read` + `awk` (no `sed -i`).
- Publish only on success: `cp -rf "$OUT"/. "$NESTDIR/<sys>/"`, then
  `touch` the stamp, `rm -rf` the stage dirs, `trap - EXIT`.

`PREFIX` is the search path (earlier packages), `OUT` the install target:
recipes pass `-DCMAKE_INSTALL_PREFIX=$OUT` / `--prefix=$OUT` and read
deps from `$PREFIX`. Both plus `RECIPEDIR`/`PACKAGEDIR`/`NESTDIR` are
exported shell vars, never baked absolute paths (except the script
header, which absolutizes `--nest`/`--packages` so the script is
cwd-independent).

## Writing a source recipe (`source.lua`)

Fetch-only. Pattern:

```lua
return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zlib.tar.gz ]; then
          curl -fSL -C - -o dl/zlib.tar.gz "https://host/zlib-1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zlib.tar.gz -C src --strip-components=1
        mkdir -p $OUT/zlib
        cp -r src/* $OUT/zlib/
    ]]
})
```

- Tarball in `dl/`, skip re-download with `if [ ! -f ... ]`. Resume with
  `curl -C -`. Mirrors: `|| curl ... mirror` on the same line.
- Unpack to `src/`, then `mkdir -p $OUT/<name>` + `cp -r src/* $OUT/<name>/`.
  `@source` never compiles — it only stages sources.
- No checksums (project decision).
- Tarballs are preferred, but `git clone` is a first-class source too —
  use it whenever upstream has no usable tarball (only git tags) or the
  tarball is known-incomplete (missing git submodules, like protobuf or
  onnx historically were). Pattern (fields `git`/`tag` become shell vars
  via the emitter, see `packages/python/source.lua` which was fetch-by-git
  from the start):
  ```lua
  return recipe({
      version = "3.14.7",
      git = "https://github.com/python/cpython",
      tag = "v3.14.7",
      build = [[
          if [ ! -d src ]; then
            git clone --depth=1 --branch "$tag" "$git" src
          fi
          mkdir -p $OUT/python
          cp -r src/* $OUT/python/
      ]]
  })
  ```
  Add `--recursive` when the build needs submodule content
  (`git clone --depth=1 --recursive --branch "$tag" "$git" src`).
  Guard with `if [ ! -d src ]` so re-runs are idempotent (same role as
  the `if [ ! -f dl/... ]` tarball guard). Shallow (`--depth=1`) always —
  full history is never needed for a build.

## Writing a build recipe (`generic.lua`)

Requires first, one `recipe()` at the end:

```lua
require("zlib")
require("libpng@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/libpng/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS --with-zlib-prefix="$PREFIX"
        make
        make install
    ]]
})
```

Rules:

- `require("dep")` inherits your system; `require("dep@sys")` pins one
  (explicit always wins). `require("ownname@source")` pulls your sources,
  copied from `$NESTDIR/source/<name>/` (not `$OUT`).
- Build-system flags come from the system, never hardcoded:
  `$CMAKE_FLAGS`, `$AUTOCONF_CONFIGURE_FLAGS`, `$MESON_FLAGS`.
  Search flags (`CPPFLAGS`, `LDFLAGS`, `PKG_CONFIG_*`) also come from the
  system — never `export` them in a recipe. Exception: recipe-local
  workarounds with a comment explaining why (e.g. readline needs
  `CFLAGS="$CFLAGS -fPIC"` because python links it into a shared module;
  termcap needs `CC="$CC -std=gnu89"` because it predates prototypes).
- Build-body hygiene (hard rules): only `cp`, `./configure`, `cmake`,
  `make`, `make install`, `touch`, `find`, `mkdir`, `cat`-heredocs.
  NEVER `sed`, patches, `/dev/null`, or multi-job builds. Build serially:
  use `make -j1` or the build tool's equivalent single-job option. This
  keeps logs readable and ordering deterministic.
  (Legacy violation: `packages/opencv/generic.lua` uses
  `cmake --build build -j$(nproc ...)`; change it to one job before running
  or otherwise touching it.)
- Autotools timestamp guard after every `./configure` (tarball mtimes
  trigger `aclocal-1.17` re-runs we don't have):
  `touch aclocal.m4 configure config.h.in` +
  `find . -name 'Makefile.in' | xargs touch`
  (also `Makefile.pre.in` for python).
- Old C code (termcap 1.3.1): `export CC="$CC -std=gnu89"`.
  Old `bool`-typedef code: `-std=gnu17` (NDK clang defaults to C23).
- `make install` installs straight into `$OUT` (`--prefix=$OUT` /
  `-DCMAKE_INSTALL_PREFIX=$OUT`); the emitter merges `$OUT` verbatim.
- Per-buildsystem notes: cmake needs
  `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` for old projects under cmake 4.x;
  meson cross files live in `$SYSDIR`; cargo needs
  `PKG_CONFIG_ALLOW_CROSS=1` + `RUSTFLAGS="-L $PREFIX/lib"`;
  libvpx configure wants `--extra-cflags="--sysroot=$SYSROOT"`, not
  `-isystem` (breaks libc++ include order).
- Name-mismatch traps: mingw zlib installs as `libzlib`, but libpng
  `configure` hardcodes `-lz` — the libpng recipe symlinks
  `libz.* → libzlib.*` in `$PREFIX` first (commented, additive).

## Writing a system (`<sys>/generic.lua`)

Single `system({ setup = [[...]] })` with `VAR="value"` + grouped
`export` lines. Sections with `# ---` comments:

```sh
# --- toolchain: NDK clang wrappers + llvm binutils ---
CC="aarch64-linux-android24-clang"
...
export CC CXX AR ...
# --- search paths: our prefix first, NDK sysroot second ---
CPPFLAGS="-I$PREFIX/include"
...
# --- build-system defaults: install into $OUT, find in $PREFIX ---
AUTOCONF_CONFIGURE_FLAGS="--host=aarch64-linux-android --build=x86_64-pc-linux-gnu"
...
```

Rules:

- Every cross system sets `AUTOCONF_CONFIGURE_FLAGS` with **both**
  `--host=<triplet>` and `--build=x86_64-pc-linux-gnu` (python's configure
  errors out without an explicit `--build`; others guess fine but
  uniformity wins).
- `--prefix=$OUT` / `-DCMAKE_INSTALL_PREFIX=$OUT` (install target),
  search flags point at `$PREFIX` (where deps landed).
- Keep values short: build long ones by appending
  (`FOO="$FOO more"`), one `export A B C` per section, comments
  explaining non-obvious choices (why `-isystem` is C-only, why `LDFLAGS`
  is empty for cargo, why the NDK glob avoids `ls`).
- cmake toolchain + meson crossfile go next to `generic.lua`, referenced
  as `$SYSDIR/<file>` (never generated heredocs in the script).
- New API level = copy the whole `<arch>-androidNN/` dir, rename every
  `NN` in wrapper names, `--host`, file names, error strings. Existing
  `android21` dirs stay untouched.

## Workflow

```sh
ninja -C builddir retrolunar          # rebuild after loader/C changes
./builddir/retrolunar install --nest ./nest --packages ./packages 'pkg@sys' > build.sh
sh -n build.sh                        # syntax gate, always
ANDROID_HOME=/path/to/sdk sh build.sh # NDK systems need this
```

- When asked to add package(s), implement them and run their build on one
  suitable provided system. Preserve `./nest` and reuse its successful
  outputs; do not delete it or force dependency rebuilds unless necessary.
- When asked to update package(s), update exactly the requested scope. Check
  each package's latest stable upstream release, then update its version,
  source URL or git tag, and any build recipe details that changed. Preserve
  existing system support; change system-specific recipes only when needed,
  and leave unrelated packages and systems untouched. If an upstream release
  cannot be used on the supported systems, report the concrete blocker.
  Build each updated package on one suitable provided system, serially,
  reusing `./nest` and avoiding dependency rebuilds unless necessary.
- Use `jj` (not `git`) for repository commits. Commit each completed logical
  change promptly; package work gets one commit per package
  (`jj commit -m 'name version (what it is)'`). Keep `./nest` between builds
  so fresh deps aren't rebuilt; record failures as `'<name> version attempt
  (blocked: reason)'` commits only if sources were added, otherwise just
  drop the files.
- Verify per package: artifact exists (`lib/libfoo.a`,
  `bin/tool`, `include/foo.h`), `pkg-config --modversion foo` if a `.pc`
  ships, rerun prints `skip ... (fresh)`.
- Known platform walls (don't re-investigate, work around or drop):
  API 21 lacks `stderr` as a real symbol, `POSIX_MADV_*`,
  `process_vm_readv`, `posix_spawn`, `mblen`/`getpass`, `O_BINARY` —
  anything needing them wants API 24+ or gets dropped (wget, bash, ninja,
  llama.cpp). `sfml` is X11-only, `raylib` uses removed NDK APIs.
- No `jj`/`git` commands inside recipes; no network access at build time
  except `curl` in `source.lua` fetch blocks.
