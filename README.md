# retrolunar

A tiny package manager: a C binary with an embedded Lua 5.5 interpreter
that prints POSIX shell scripts which build Unix software — natively or
cross-compiled for Android — into isolated per-system prefixes.

## Quick start

Prerequisites: `meson`, `ninja`, a C compiler, `curl`, `git`, `sh`, and
`flock` from util-linux.
For Android targets: an Android SDK with an NDK (`ANDROID_HOME`).

```sh
# 1. Build retrolunar itself.
meson setup builddir && ninja -C builddir retrolunar

# 2. Generate the build script for what you want.
./builddir/retrolunar install --nest ./nest --packages ./packages \
  'python@aarch64-android24' > build.sh

# 3. Check it, then run it.
sh -n build.sh
ANDROID_HOME=/path/to/android-sdk sh build.sh
```

The `install` arguments are one or more `pack[@sys]` targets: `pack`
alone inherits the compile-time default system (`DEFAULT_SYSTEM`,
`clang-native` by default); `pack@sys` pins a system. The magic
`pack@native` spelling aliases that default—it does not name a separate
target system. Dependencies resolve automatically — asking for `python`
also builds `readline`, `termcap`, and their sources first.

## Where things go after building

Everything lives under `--nest` (here `./nest`, gitignored):

- `./nest/<sys>/` — the usable prefix for a system: `bin/`, `lib/`,
  `include/`, `lib/pkgconfig/`. **This is what you consume.**
  Point your builds at it:
  - `./nest/aarch64-android24/bin/python3`
  - `CC=aarch64-linux-android24-clang CFLAGS=-I./nest/aarch64-android24/include LDFLAGS=-L./nest/aarch64-android24/lib`
  - `PKG_CONFIG_LIBDIR=./nest/aarch64-android24/lib/pkgconfig pkg-config --libs libcurl`
- `./nest/source/<name>/` — unpacked upstream sources per package.
  Useful for debugging build failures (the real `configure` logs and
  Makefiles live in `./nest/tmp/work-*/` while a build runs, but those
  are removed on success).
- `./nest/<sys>/.retrolunar-<name>` — freshness stamps. Re-running the
  script prints `skip pack@sys (fresh)` for anything whose stamp is
  newer than its recipe, its system file, and its system dir. Touch a
  recipe or delete a stamp to force a rebuild of just that package.
- `./nest/tmp/` — scratch space (`WORK`/`OUT` stage dirs, one pair per
  package, cleaned via `trap` even on failure). Safe to delete any time
  nothing is building.

Downstream use pattern: after `sh build.sh`, export the prefix and build
your own code against it — headers, static libs, `.pc` files, and tools
(`bin/python3`, `bin/meson`-style wrappers where packages ship them)
are all under `./nest/<sys>/`.

## CI example

`.github/workflows/build-deps.yml` (or any CI with the same steps):

```yaml
name: deps
on: [push]
jobs:
  android-deps:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install host tools
        run: sudo apt-get update && sudo apt-get install -y
          meson ninja-build curl git pkg-config cmake autoconf make util-linux
      - name: Install Android SDK + NDK
        uses: android-actions/setup-android@v3
      - name: Build retrolunar
        run: meson setup builddir && ninja -C builddir retrolunar
      - name: Generate + run dependency script
        env:
          ANDROID_HOME: ${{ env.ANDROID_HOME }}
        run: |
          ./builddir/retrolunar install \
            --nest ./nest --packages ./packages \
            'python@aarch64-android24' > build.sh
          sh -n build.sh
          sh build.sh
      - name: Check artifacts
        run: |
          test -x nest/aarch64-android24/bin/python3
          PKG_CONFIG_LIBDIR=$PWD/nest/aarch64-android24/lib/pkgconfig \
            pkg-config --modversion readline
      - uses: actions/upload-artifact@v4
        with:
          name: aarch64-android24-prefix
          path: nest/aarch64-android24
          # Consumers download this artifact and use it as their PREFIX:
          # headers in include/, libs in lib/, tools in bin/.
```

Notes for CI:

- Cache `./nest/source` (tarballs + git clones) between runs — it makes
  rebuilds incremental; the freshness stamps skip everything already
  built. Do **not** cache `./nest/tmp`.
- `sh -n build.sh` first: rejects a broken generated script before the
  hour-long build starts.
- `ANDROID_HOME` must point at an SDK containing an NDK; the system
  `setup` picks the newest `ndk/*` automatically.
- After the run, the `aarch64-android24` artifact dir **is** the SDK for
  your app jobs: unpack it, set `PREFIX`, `PKG_CONFIG_LIBDIR`, `CC`,
  and link away. Nothing else from the repo is needed at consumption
  time — the generated script already ran.

## Packages and systems

See [AGENTS.md](AGENTS.md) for the full guide: `require("pack")` vs
`require("pack@sys")`, writing `source.lua` (fetch-only) and
`generic.lua` (build) recipes, writing `system({ setup = ... })`
environments (toolchain, search paths, build-system defaults), recipe
hygiene rules (no `sed`/patches/`/dev/null`/parallel make), and the
known platform walls (API 21 vs 24+, X11-only or NDK-removed APIs).
