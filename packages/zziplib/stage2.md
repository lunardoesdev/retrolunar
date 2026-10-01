ACCEPT

# zziplib review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, zziplib 0.13.78 (Debian
`+dfsg.1` repack of the upstream tarball). Tarball verified with `tar tf`
(299 entries, top dir `zziplib-0.13.78/`), extracted to
`/home/si/.revE/src2/zziplib-0.13.78`.

## 1. Is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS …`, `cmake --build build --parallel 1`,
`cmake --install build` with no `--prefix` override (correct —
`-DCMAKE_INSTALL_PREFIX=$OUT` is already in `$CMAKE_FLAGS`). `require("zlib")`
is a real package. No hardcoded triplet/API/march, no `export` of search
flags, no `DESTDIR`, no `sed`/patch in the recipe itself.

## 2. Is it doing what the package needs?

**Every option passed exists, with the stated defaults.** All eight verified
as real `option()` calls:

| option | where | default | recipe | exists |
|---|---|---|---|---|
| `BUILD_SHARED_LIBS` | `CMakeLists.txt:11` | ON | `OFF` | yes |
| `ZZIPMMAPPED` | `:18` and `zzip/CMakeLists.txt:20` | ON | untouched | yes |
| `ZZIPFSEEKO` | `:19` and `zzip/CMakeLists.txt:21` | ON | `OFF` | yes |
| `ZZIP_COMPAT` | yes | — | `OFF` | yes |
| `ZZIP_PKGCONFIG` | yes | — | left ON | yes |
| `ZZIPSDL` / `ZZIPWRAP` / `ZZIPBINS` / `ZZIPTEST` / `ZZIPDOCS` | yes | — | `OFF` | yes |

No nonexistent flag. cmake's own `BUILD_SHARED_LIBS` is a standard option.

**"Pure C, not old C++" is correct and worth having been checked.** The recipe
comment explicitly rejects a premise ("this is 'old C++'") and I confirmed it:

```
$ find . -name '*.cpp' -o -name '*.cc' -o -name '*.hpp' | wc -l   → 0
$ head -3 CMakeLists.txt
project(zziplib VERSION "0.13.78" LANGUAGES C)
```

Zero C++ files in the whole tree and the project declares `LANGUAGES C`. So no
`-std=` override is needed — which matters here, because a stale "old C++"
assumption would have produced exactly the kind of hardcoded target fact
AGENTS.md forbids.

**The retired autotools claim is right.** `ls` in the tree root shows
`old.configure.ac` present and **no** `configure` and **no** `configure.ac`.
So the autotools route would need `autoreconf` — the same hygiene question
that decides cmph/minizip — and cmake is the correct choice. The recipe's
reasoning is the wolfssl pattern: choose the other build system rather than
invoke `autoreconf`. Correct, and it means zziplib does not inherit that
defect.

**`ZZIPDOCS=OFF` is genuinely mandatory.** `docs/CMakeLists.txt:23` is
`find_package(PythonInterp 3.5 REQUIRED)` — a hard configure failure without
a host interpreter on a cross build. Right to switch off.

**The `sed`-inside-cmake argument is sound and important.** The recipe notes
that `ZZIP_PKGCONFIG` generates `zziplib.pc` via a `${BASH} -c "… sed …"`
custom command (`zzip/CMakeLists.txt:233`) and argues this is permitted
because it edits files cmake itself produced in this run. That is the correct
reading of AGENTS.md: the prohibition is on the *recipe* sed-ing upstream
sources, not on upstream's own build steps running sed over generated output.
`ZZIP_COMPAT=OFF` is then switched off partly to avoid the same pattern at
`zzip/CMakeLists.txt:190`. Well reasoned, and the distinction is drawn in the
right place.

**`ZZIPMMAPPED` left ON is a defensible judgement.** `CMakeLists.txt:18`
labels it "not fully portable", which sounds like a warning — but the recipe
argues it refers to mmap-based seeking that zziplib only uses when the caller
asks, and it is upstream's headline feature. Keeping it while switching off
the redundant `ZZIPFSEEKO` (`libzzipfseeko`) is the right shape: you get one
seek implementation, not two. I verified both options default ON, so
`-DZZIPFSEEKO=OFF` is a real narrowing, not a no-op.

**No host program is compiled or executed.** With `ZZIPBINS`/`ZZIPTEST`/
`ZZIPDOCS`/`ZZIPWRAP`/`ZZIPSDL` all off, the CLI tools, the tests and the
Python-driven docs are never added. zlib is a real dependency in this prefix
and resolves through `-DCMAKE_PREFIX_PATH=$PREFIX`.

**API gates: none material.** zziplib is zlib-backed ZIP I/O; its libc surface
is `mmap`/`fseeko`/`read`/`write`, all present from Bionic's earliest API. No
`nl_langinfo`, `iconv_open`, `posix_spawn`, `mktime_z`, `O_BINARY`,
`POSIX_MADV_*` or `process_vm_readv`.

## Artifacts — what actually installs

- `lib/libzzip.a` — plus, with `ZZIPMMAPPED` on, `lib/libzzipmmapped.a`
- `include/zzip/*.h` (zzip.h, zconf.h, zip.h, …)
- `lib/pkgconfig/zziplib.pc` — `ZZIP_PKGCONFIG` left ON deliberately
- **No `libzzip.so` and no `.la`** — static via `BUILD_SHARED_LIBS=OFF`. The
  `libzzip_links`/`libzzip_latest` symlink targets at `zzip/CMakeLists.txt:184-199`
  become no-ops, which is what we want.
- **No `$OUT/bin`** — `ZZIPBINS=OFF` means no `zzip`/`unzip` wrappers.

## Source provenance

Upstream is SourceForge, which the recipe records as answering HTTP 522 from
this network on every mirror tried; it fetches Debian's `+dfsg.1` repack
instead. I fetched that repack independently: 558,584 bytes, `tar tf` clean,
299 entries, top dir `zziplib-0.13.78/`. The `+dfsg` repack strips
non-free bits; the cmake sources and headers are intact, which is what this
build needs.

## Forecast

I believe **5 of 6**: the five cross rows and clang-native are all UNCERTAIN,
and I agree with every one being UNCERTAIN rather than upgraded.

UNCERTAIN is the honest verdict here and the adder is right not to have
manufactured a green: nothing in the recipe's option set is *wrong*, but the
build has not been run, and zziplib is old enough (0.13.x, cmake
`cmake_minimum_required(VERSION 3.1)`) that toolchain-era surprises are
plausible. Per AGENTS.md "UNCERTAIN is a legitimate answer. 'Looks fine' is not
an answer" — and the risk section backs it with specific things to check
(the `sed`-in-cmake argument, the mmapped portability note, the symlink
no-ops) rather than vague hedging.

I would **not** upgrade these rows without a build. Recording six UNCERTAIN
rows for a package whose recipe I have verified option-by-option is the
correct amount of confidence.

## Carried to the build

```sh
# 1. artifacts (expected: all present). No .so, no .la, no bin/ — each absence
#    is one of the recipe's switches, so they are checks, not gaps.
test -f "$OUT/lib/libzzip.a"            || echo "MISSING libzzip.a"
test -f "$OUT/lib/libzzipmmapped.a"     || echo "MISSING libzzipmmapped.a (ZZIPMMAPPED left ON)"
test -d "$OUT/include/zzip"             || echo "MISSING zzip headers"
test -f "$OUT/lib/pkgconfig/zziplib.pc" || echo "MISSING zziplib.pc"
find "$OUT/lib" -name 'libzzip*.so*' | wc -l   # expected 0
find "$OUT/lib" -name '*.la' | wc -l            # expected 0
test -d "$OUT/bin" && find "$OUT/bin" -type f | head   # expected: no CLI tools

# 2. static, scoped by zziplib's own library names
find "$OUT/lib" -name 'libzzip.*' | grep -c '\.a$'   # expected >= 1

# 3. version expected 0.13.78
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion zziplib

# 4. no $OUT left in the .pc — proves the loader rewrite ran (src/loader.lua:454)
grep -c "$OUT" "$OUT/lib/pkgconfig/zziplib.pc"      # expected 0

# 5. the switch set, read from the cache rather than assumed
grep -E '^(BUILD_SHARED_LIBS|ZZIPMMAPPED|ZZIPFSEEKO|ZZIP_COMPAT|ZZIPTEST|ZZIPBINS|ZZIPDOCS|ZZIPSDL|ZZIPWRAP):' \
     "$WORK/build/CMakeCache.txt"
# expected: BUILD_SHARED_LIBS=OFF, ZZIPMMAPPED=ON, ZZIPFSEEKO=OFF, and the rest OFF

# 6. THE ZZIPDOCS CHECK: find_package(PythonInterp 3.5 REQUIRED) at
#    docs/CMakeLists.txt:23 must never have run.
grep -i 'PythonInterp' "$WORK/build/CMakeCache.txt" | head -1
echo "(no output above = docs/ was never added)"

# 7. zlib must come from THIS prefix, not a system one
llvm-nm -u "$OUT/lib/libzzip.a" | grep -cwE 'deflate|inflate|crc32'   # expected >=1
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --libs zziplib | tr ' ' '\n' | grep -c '^-L'

# 8. ELF machine per family
$OBJDUMP -f "$OUT/lib/libzzip.a" | head -3
```

Note: `$WORK/build/CMakeCache.txt` is trap-removed at block end — read it during
the block or copy it out.