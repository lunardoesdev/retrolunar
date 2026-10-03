# retrolunar

A small package manager. It's one C binary with Lua 5.5 baked in, and
what it actually does is print shell scripts — ordinary `sh` scripts that
build Unix software for your machine or for Android, into a prefix per
system. Nothing clever at build time, no daemon, no dependency solver
running in the background. You get a script, you can read it, you can edit
it, you can throw it away and generate it again.

## Build it

```sh
meson setup builddir
ninja -C builddir
```

You need `meson`, `ninja`, a C compiler, and `python3`. At runtime:
`sh`, `curl`, `git`, and `flock` (from util-linux). For Android targets,
an SDK with an NDK in `ANDROID_HOME`.

Install it into `~/.local/bin` when you'd rather not have `./builddir/` in
front of every command:

```sh
meson setup builddir --prefix "$HOME/.local"
ninja -C builddir && meson install -C builddir
export PATH="$HOME/.local/bin:$PATH"
```

Or system-wide, same thing with a different prefix and `sudo`:

```sh
sudo meson setup builddir --prefix /usr/local
sudo ninja -C builddir && sudo meson install -C builddir
```

That puts `retrolunar` in `/usr/local/bin` plus a `liblua.a` that nothing
else needs. The binary is self-contained, so it doesn't care that the repo
moved or vanished. To undo it, delete those two files.

## Your first build

```sh
retrolunar generate -x 'pngprobe@aarch64-android24'
```

That's the whole thing. First run clones a packages tree into
`~/.cache/retrolunar/packages` (and refreshes it later with `git pull`),
resolves the recipes, writes a build script, runs it, and hands you back
an Android prefix.

No packages tree on hand? Point `--packages` at one you keep yourself:

```sh
git clone https://github.com/lunardoesdev/retrolunar-packages
retrolunar generate --packages ./retrolunar-packages -x 'pngprobe@aarch64-android24'
```

## The four commands

### generate — write the build script

`generate` is the one you'll use most. It resolves your targets and emits
a POSIX `sh` script.

```sh
retrolunar generate 'python@aarch64-android24' > build.sh   # to stdout
retrolunar generate -o build.sh 'python@aarch64-android24'    # to a file, chmod +x
retrolunar generate -x 'python@aarch64-android24'            # and run it
retrolunar generate -o build.sh -x 'python@aarch64-android24'
```

`-o FILE` writes the script and makes it executable, so you can look at it,
keep it, run it again next week. `-x` runs it with `sh` straight away and
exits with whatever the script exited with — if a recipe fails, so does
the command, which is what you want in a script or a CI job.

Builds are serial by default. `--cores N` raises the job count for
recipes that ask for it:

```sh
retrolunar generate -x --cores 8 'python@aarch64-android24'
```

The generated script opens with `export CORES=1`; with `--cores 8` it
opens with `export CORES=8`. Recipes read `$CORES` and decide for
themselves — most still build one job at a time, because a log you can
read is worth more than the wall-clock.

`install` is the same thing without the options: it only ever prints to
stdout. Useful for piping.

### deps — just tell me what it would build

```console
$ retrolunar deps 'pngprobe@aarch64-android24'
zlib@source 1.3.1
zlib@aarch64-android24
libpng@source 1.6.48
libpng@aarch64-android24
freetype@source 2.13.3
freetype@aarch64-android24
pngprobe@aarch64-android24 0.1.0
```

Dependencies first, what you asked for last, version when the recipe
pins one. Nothing is downloaded, compiled, or written. Fast way to answer
"why is this taking so long".

### search — what's in the tree

```console
$ retrolunar search png
libpng                   package  generic, source
pngprobe                 package  generic
```

Case-insensitive substring. `system` means a toolchain definition;
`package` lists the recipe files it ships — `generic` is the
system-neutral fallback, `source` fetches the tarball, `android` and
friends override per system.

```console
$ retrolunar search bc
bc                       package  generic, source, android
```

`retrolunar search ''` lists the whole tree.

### install — print the script

```sh
retrolunar install 'python@aarch64-android24' > build.sh
sh -n build.sh && sh build.sh
```

### About targets

Every command takes `pack` or `pack@sys`:

```sh
retrolunar generate -x zlib                 # default system: clang-native
retrolunar generate -x 'zlib@aarch64-android24'
retrolunar generate -x 'zlib@x86_64-mingw'
```

A bare name means the compile-time default system (`clang-native`, unless
you change it at build time). `@native` is another way of spelling that
same default. Dependencies come along automatically; you never list them.

If you name a system that doesn't exist, you find out immediately:

```console
$ retrolunar deps 'zlib@sdfkjsdlkf'
system 'sdfkjsdlkf' not found (needed by 'zlib'): module 'sdfkjsdlkf@generic' not found
$ echo $?
1
```

## Where output lands

Two paths, both optional:

- `--packages DIR` — the packages tree. Defaults to
  `~/.cache/retrolunar/packages`, cloned on first use.
- `--nest DIR` — where prefixes are built. Defaults to
  `~/.cache/retrolunar/nestdir`, so builds don't scatter into your source
  tree and the next run can reuse them.

Point them wherever you like. CI usually wants `--nest ./nest` so the
prefix is in the workspace.

Inside a nest:

```
nest/
  aarch64-android24/      the usable prefix — this is what you consume
    bin/ lib/ include/ lib/pkgconfig/
  source/                 unpacked upstream tarballs, kept between runs
  tmp/                    per-package scratch, cleaned up after each build
  .retrolunar.lock        held for the duration of a build
```

The prefix is a normal prefix. Headers, static libs, `.pc` files, tools:

```sh
nest/aarch64-android24/bin/python3

CC=aarch64-linux-android24-clang \
CFLAGS="-I$PWD/nest/aarch64-android24/include" \
LDFLAGS="-L$PWD/nest/aarch64-android24/lib" \
  cc -o mine mine.c

PKG_CONFIG_LIBDIR="$PWD/nest/aarch64-android24/lib/pkgconfig" \
  pkg-config --libs --cflags libcurl
```

## It's incremental

Every package gets a stamp. Run the same command again and finished work
is skipped:

```console
$ retrolunar generate -x 'pngprobe@aarch64-android24'
...
$ retrolunar generate -x 'pngprobe@aarch64-android24'
skip zlib@source (fresh)
skip zlib@aarch64-android24 (fresh)
...
```

When the script finishes, it tells you where it put everything:

```console
$ retrolunar generate -x 'pngprobe@aarch64-android24'
...

retrolunar: installed under: /home/you/.cache/retrolunar/nestdir
retrolunar:   aarch64-android24: /home/you/.cache/retrolunar/nestdir/aarch64-android24
```

One line per system that actually got written to. It only prints when
stdout is a terminal, so piping a build into a log stays clean.

A stamp is newer than its recipe, its system file and its system dir, so
editing any of those rebuilds just what's affected. To force one package,
delete its stamp:

```sh
rm nest/aarch64-android24/.retrolunar-zlib
```

Two builds can't share a nest. The second one to start fails immediately
rather than waiting — the lock is held for the whole run and released by
the kernel even if the build is killed.

## Recipes

Recipes are Lua files, and a package is a directory:

```
packages/zlib/
  source.lua      fetch and unpack upstream
  generic.lua     build it
  android.lua     optional: only for Android
```

```lua
-- generic.lua
require("libpng@source")

return recipe({
    build = [[
        ./configure --prefix="$OUT"
        make
        make install
    ]]
})
```

Build bodies get `$CORES`, `$PREFIX`, `$OUT` and friends as environment.
Honouring `$CORES` is optional and off by default:

```lua
    build = [[
        make -j"$CORES"
        make install
    ]]
```

One `pack` resolves to at most one file: the exact system first, then the
system's `recipe_fallbacks` in order, then `generic.lua`. That's why one
`android.lua` covers every Android target.

[AGENTS.md](AGENTS.md) has the full guide — the loader's `require`
forms, the freshness rules, what recipes are and aren't allowed to do, and
the platform walls worth knowing before you try to build something.

## Scripts

Because the output is just `sh`, wrapping it is easy.

### Build and use a toolchain

```sh
#!/bin/sh
# build-deps.sh — produce an Android prefix other jobs can consume
set -eu

: "${ANDROID_HOME:?set ANDROID_HOME to an SDK with an NDK}"
SYS=aarch64-android24
NEST="$PWD/nest"

retrolunar generate -o "build-$SYS.sh" -x --nest "$NEST" "python@$SYS"

PREFIX="$NEST/$SYS"
test -x "$PREFIX/bin/python3"
PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" pkg-config --modversion readline

echo "prefix ready: $PREFIX"
```

### Keep the cache, throw away the rest

```sh
# source/ holds downloaded tarballs; tmp/ never survives a run.
cache: nest/source
```

In a CI config that's two lines:

```yaml
cache:
  paths: [nest/source]
```

### See what changed before you rebuild

```sh
#!/bin/sh
set -eu
SYS=aarch64-android24

retrolunar generate -o build.sh --nest ./nest "python@$SYS"
sh -n build.sh                       # catch a broken script early
diff -u previous-build.sh build.sh || echo "recipe set changed"
sh build.sh
cp build.sh previous-build.sh
```

### Per-API-level Android prefixes

```sh
#!/bin/sh
set -eu
NEST="$PWD/nest"
export ANDROID_HOME="${ANDROID_HOME:?set ANDROID_HOME}"

for level in 21 24 35; do
  echo "=== android$level ==="
  retrolunar deps "pngprobe@aarch64-android$level" || continue
  retrolunar generate --nest "$NEST" -o "build-$level.sh" -x \
    "pngprobe@aarch64-android$level"
done
```

Not every package builds on every API level, so `deps` first: it tells
you whether the recipe chain even resolves before you spend an hour
finding out.

### Just look at what you'd get

```sh
# what does python drag in, and for which systems?
retrolunar deps 'python@aarch64-android24'

# is there anything for this name at all?
retrolunar search ncurses

# write it out, look at it, decide
retrolunar generate -o review.sh 'python@aarch64-android24'
less review.sh
```

## Notes

- The generated script takes a `flock` on the nest, so two runs against
  the same nest can't overlap. Different nests run happily side by side.
- Recipes never run target binaries. Nothing is emulated. If a package
  needs to run its own freshly built tool to finish configuring, that
  package does not build here.
- `deps` and `search` don't need a nest and don't touch one.