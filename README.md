# retrolunar

A tiny package manager: a C binary with an embedded Lua 5.5 interpreter
that prints POSIX shell scripts which build Unix software — natively or
cross-compiled for Android — into isolated per-system prefixes.

## Quick start

Prerequisites: `meson`, `ninja`, a C compiler, `curl`, `git`, `sh`, and
`flock` from util-linux.
For Android targets: an Android SDK with an NDK (`ANDROID_HOME`).

`--packages` points at a packages tree; it is optional. Left out, the tree
is taken from `$HOME/.cache/retrolunar/packages`, cloned from
<https://github.com/lunardoesdev/retrolunar-packages> on first use and
refreshed with `git pull --ff-only` afterwards:

```sh
retrolunar deps 'python@aarch64-android24'   # clones the tree, then lists
```

A failed refresh is ignored — a tree that is already there is good enough
to resolve against, so an offline run still works. A tree that cannot be
obtained at all (no `HOME`, clone failed, directory left empty by an
interrupted clone) is an error: `retrolunar` says so and exits 1 rather
than resolving against nothing. Pass `--packages DIR` to use a tree you
keep somewhere else, as the CI example below does.

```sh
# 1. Build retrolunar itself.
meson setup builddir && ninja -C builddir retrolunar

# 2. Generate the build script for what you want.
./builddir/retrolunar install 'python@aarch64-android24' > build.sh

#    --nest defaults to $HOME/.cache/retrolunar/nestdir

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

`--nest` is optional. Without it, prefixes land in
`$HOME/.cache/retrolunar/nestdir`, which keeps them out of the source
tree and lets successive builds share one cache. Pass `--nest DIR` to put
them somewhere specific, as the CI example below does. If `HOME` is unset
and you omit `--nest`, `install` prints the usage message instead of
guessing a location.

## Listing dependencies

`deps` resolves the same queue `install` would build and prints it, one
`name@sys` per line, in dependency order — leaves first, the packages you
asked for last:

```sh
retrolunar deps 'python@aarch64-android24'
```

```
termcap@aarch64-android24
readline@aarch64-android24 8.2
python@aarch64-android24 3.14.7
```

The version is printed when the recipe set one. It prints the result and
nothing more: no build script is written, no tarball is downloaded,
nothing is compiled, and the nest is neither read nor created. What it
does do is the packages bootstrap described under Quick start, so the
first `deps` on a machine without a packages tree clones one.
`--nest` does not apply to `deps`. An unknown target fails with the module
error and exit 1, as `install` does.

It takes the same `pack[@sys]` targets as `install`, including bare names
and the `@native` alias, and several at once.

## Searching the packages tree

`search` lists packages and systems whose name contains the query,
case-insensitively:

```sh
retrolunar search png
```

```
libpng                   package  generic, source
pngprobe                 package  generic
```

Systems are reported as `system`, packages as `package` followed by the
recipe files they ship — `generic` (the system-neutral fallback), `source`
(the fetch recipe) and any per-system recipe such as `android`:

```sh
retrolunar search bc
```

```
bc                       package  generic, source, android
```

An empty query lists everything:

```sh
retrolunar search ''
```

Like `deps`, it reads the tree only — no recipe is run, nothing is compiled,
and the nest is not touched. It does run the packages bootstrap,
so the first `search` on a machine without a packages tree clones one.
`search` with no query at all is a usage error.

## Installing retrolunar

`meson setup` records the install prefix, so the prefix is fixed at setup
time and `meson install` just uses it. Build first — `meson install`
refuses to run in an unbuilt build dir.

### To `~/.local/bin` (per user, no root)

```sh
meson setup builddir --prefix "$HOME/.local"     # ~/.local/bin/retrolunar
ninja -C builddir
meson install -C builddir
```

Make sure `~/.local/bin` is on your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

To move an existing build dir to a different prefix later, reconfigure
with `meson configure builddir --prefix "$HOME/.local"`, then
`ninja -C builddir && meson install -C builddir`. The binary lands in
`<prefix>/bin/retrolunar` and a static `liblua.a` in `<prefix>/lib/`.

### To the system (`/usr/local`, needs root)

```sh
sudo meson setup builddir-system --prefix /usr/local
sudo ninja -C builddir-system
sudo meson install -C builddir-system
```

That installs `/usr/local/bin/retrolunar`, which is on `PATH` on most
distributions. If `sudo` is not available or you prefer to see what a
root step does, stage the install with `--destdir` and inspect it first:

```sh
meson install -C builddir --destdir "$PWD/stage"
find stage -type f          # stage/usr/local/bin/retrolunar, stage/usr/local/lib/liblua.a
sudo cp -a stage/usr/local/. /usr/local/
rm -rf stage
```

`retrolunar` is self-contained — it links its embedded Lua statically,
so the installed binary has no runtime dependency on the repo. It does
need `git` and network access on first run, to clone the packages tree
into `$HOME/.cache/retrolunar/packages` (see Quick start); that cache is
separate from the install prefix and is not touched by uninstalling.

### Uninstall

```sh
# per-user, prefix $HOME/.local
rm ~/.local/bin/retrolunar ~/.local/lib/liblua.a

# or, for a /usr/local install
sudo rm /usr/local/bin/retrolunar /usr/local/lib/liblua.a
```

Uninstalling removes those two installed files. It does not touch any
nest you built with `--nest`; delete the nest directory yourself if you
want the prefixes gone.

## Where things go after building

Everything lives under `--nest` (`./nest` in the CI example below, the
default `$HOME/.cache/retrolunar/nestdir` otherwise):

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
      - name: Clone the packages tree
        run: git clone --depth=1 https://github.com/lunardoesdev/retrolunar-packages
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
            --nest ./nest --packages ./retrolunar-packages \
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
`require("pack@sys")` (including ordered `recipe_fallbacks`), writing
`source.lua` (fetch-only) and `generic.lua` (build) recipes, and writing
`system({ ... })` environments (toolchain, search paths, build-system
defaults), recipe hygiene rules (no `sed`/patches/`/dev/null`/parallel
make), and the known platform walls (API 21 vs 24+, X11-only or NDK-removed APIs).
