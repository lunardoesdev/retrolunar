ACCEPT

# mold review (stage2)

Recipe: **`clang-native.lua` only — no `generic.lua`, by design.**
Source: `source.lua`, mold 2.42.1 (git tag archive). Tarball verified with
`tar tf` (3902 entries, top dir `mold-2.42.1/`), extracted to
`/home/si/.revE/src2/mold-2.42.1`.

## 1. Is it using the SYSTEM?

Yes. `$CMAKE_FLAGS` carries `-DCMAKE_INSTALL_PREFIX=$OUT` and
`-DCMAKE_PREFIX_PATH=$PREFIX` (both exported by
`packages/clang-native/generic.lua:55-57`), and `$CC`/`$CFLAGS` come from that
system's setup (`:8`, `:25-26`). No hardcoded triplet/API/march, no `export` of
search flags, no `DESTDIR`, no `sed`/patch,
`cmake --build build --parallel 1` explicit.

## 2. Is it doing what the package needs?

**"Not Rust" is correct, and I verified it rather than trusting the note.**

```
$ ls Cargo.toml rust-toolchain        → both absent
$ find . -name '*.rs' | wc -l         → 39   (docs/scripts, not build inputs)
$ find src -type f | sed 's/.*\.//' | sort | uniq -c
     45 cc      3 h      1 c
```

45 `.cc` and 1 `.c`, zero Rust source files in `src/`. mold 2.x is pure
C/C++20, so "mold needs cargo" is stale and the recipe's comment saying so is
worth having — it stops the next reader from adding a bogus `require("cargo")`.

**`MOLD_USE_MIMALLOC=OFF` is real and correctly reasoned.** `CMakeLists.txt:201-203`:

```
cmake_dependent_option(
  MOLD_USE_MIMALLOC "Use mimalloc" ON
  "CMAKE_SIZEOF_VOID_P EQUAL 8; NOT APPLE; NOT ANDROID; NOT OPENBSD; NOT MOLD_USE_ASAN; NOT MOLD_USE_TSAN" OFF)
```

On clang-native (64-bit, Linux) the condition is satisfied, so the default is
ON and would build the vendored `third_party/mimalloc`. Turning it off keeps
the build to mold itself. That is an allocator choice, not a requirement —
correct, and it removes a third-party build from the critical path. Note
`MOLD_USE_MIMALLOC` is a `cmake_dependent_option`, so passing `OFF` explicitly
is legal and takes effect.

**`cmake --install build` rather than `--target install` is right, and the
reason is verified.** `CMakeLists.txt:484-493`:

```
function(mold_install_relative_symlink OLD NEW)
  install(CODE "
    get_filename_component(PREFIX_ABS ${CMAKE_INSTALL_PREFIX}/ ABSOLUTE)
    …
    file(CREATE_LINK ${OLD_REL} $ENV{DESTDIR}${NEW_ABS} SYMBOLIC)")
```

and `:497-503` uses it for `libexec/mold/ld`, `bin/ld.mold` and the man page.
These are relative symlinks that must be resolved against
`CMAKE_INSTALL_PREFIX` at install time. `--target install` runs the same
`install()` scripts, but `cmake --install` is the supported modern path and
what the recipe uses. Correct.

**One caveat worth recording for the builder.** Those `install(CODE)` blocks
read `$ENV{DESTDIR}` (cmake writes the variable into the script's environment;
the recipe passes no `DESTDIR`, so it expands empty, which is correct). Do not
"helpfully" add `DESTDIR=$OUT` to this recipe: `$CMAKE_INSTALL_PREFIX` is
already `$OUT`, so that would concatenate to `$OUT$OUT` — the exact meson trap
AGENTS.md warns about, in cmake clothing.

## The native-only shape — cross-cutting question 2

**A package with only `clang-native.lua` and no `generic.lua` is well-formed
for this loader, and a target system gets a sensible error.** I verified both
against the real binary rather than by reading the loader.

`src/loader.lua:181-203`'s `recipe_path` tries, in order: `<pack>/<sys>.lua`,
then the requesting system's `recipe_fallbacks`, then `<pack>/generic.lua`.
For `mold@aarch64-android24`: `mold/aarch64-android24.lua` absent;
`aarch64-android24/generic.lua` declares `recipe_fallbacks = {"android"}`, and
`mold/android.lua` is absent; `mold/generic.lua` absent. So it returns nil and
`require` raises. Observed:

```
$ ./builddir/retrolunar install … 'mold@aarch64-android24'
module 'mold@aarch64-android24' not found
```

One line, names the exact module that was asked for, no traceback, no partial
state. That is a good error, and it is what a native-only package should
produce. And on the system it *is* built for:

```
$ ./builddir/retrolunar install … 'mold@clang-native'
  cmake -S . -B build $CMAKE_FLAGS -DMOLD_USE_MIMALLOC=OFF
  cmake --build build --parallel 1
  cmake --install build
```

The build body emits correctly.

Note `AGENTS.md` says "a package may have only a `generic.lua` (pngprobe
does)" — it does not forbid the mirror image, and `bear` uses the same shape,
so the two are consistent with each other and with the loader.

**Is native-only the right call for mold, substantively?** Yes, and the reason
is not merely "it's a tool". mold is a *linker*: the host compiler driver execs
it at the end of every link. A cross-built aarch64 `mold` would sit in
`$PREFIX/bin`, could never run here (running a target binary is emulation,
which AGENTS.md forbids outright), and would be found by a host driver and fail
confusingly. The only useful mold is the host one on `$NATIVE_PREFIX/bin`,
which the loader puts first on `PATH` (`src/loader.lua:412-415`) so
`-fuse-ld=mold` resolves it. That reasoning is correct and is written down.

## Artifacts — what actually installs

- `bin/mold` — the linker proper
- `bin/ld.mold`, `libexec/mold/ld` — relative symlinks via `install(CODE)`
- `share/man/man1/mold.1`, `share/man/man1/ld.mold.1` (symlink)
- `share/doc/mold/LICENSE`

All are **host** binaries. Nothing target-shaped is produced, which is exactly
right for a native-only package.

## Forecast

I agree with **6 of 6**: five WILL NOT BUILD (one per cross system) and
clang-native WILL BUILD.

The five WILL NOT BUILD rows are correct for a structural reason — there is no
recipe for those systems — and the loader confirms the failure is a clean
"module not found" rather than a confusing one. The clang-native WILL BUILD
row rests on a recipe I have verified option by option.

## Carried to the build

```sh
# 1. artifacts. The symlinks are the point of the install(CODE) blocks, so
#    check them explicitly — and check they are symlinks, not copies.
test -x "$OUT/bin/mold"            || echo "MISSING bin/mold"
test -L "$OUT/bin/ld.mold"         || echo "MISSING or not a symlink: bin/ld.mold"
test -L "$OUT/libexec/mold/ld"     || echo "MISSING or not a symlink: libexec/mold/ld"
test -f "$OUT/share/man/man1/mold.1" || echo "MISSING man page"

# 2. the symlinks must be RELATIVE and resolve inside $OUT. An absolute link
#    pointing at the staging $OUT would break the moment $OUT is removed.
readlink "$OUT/bin/ld.mold"; readlink "$OUT/libexec/mold/ld"
# expected: "../mold" style relative paths, NOT an absolute $OUT path
grep -c "$OUT" "$OUT/bin/ld.mold" 2>/dev/null; echo "(0 = no staged path baked in)"

# 3. no mimalloc: MOLD_USE_MIMALLOC=OFF must have kept it out
grep -E '^MOLD_USE_MIMALLOC:' "$WORK/build/CMakeCache.txt"     # expected OFF
llvm-nm "$OUT/bin/mold" | grep -cw mi_ | head -1                # expected 0

# 4. host binary, and it must be usable by a host compiler
$OBJDUMP -f "$OUT/bin/mold" | head -3
# expect the BUILD host's machine (x86-64 here), NOT any target
file "$OUT/bin/mold"

# 5. the loader puts $NATIVE_PREFIX/bin first on PATH, so this is the real
#    integration check: a host link through mold must succeed
printf 'int main(void){return 0;}\n' > /tmp/m.c
"$CC" /tmp/m.c -fuse-ld=mold -o /tmp/m.out 2>&1 | head -3 && /tmp/m.out \
  && echo "OK: mold links and runs as a host linker"

# 6. confirm no Rust crept in
test -f "$WORK/build/Cargo.toml" && echo "REGRESSION: Rust build appeared"
```