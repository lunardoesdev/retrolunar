ACCEPT

# bear review (stage2)

Recipe: **`clang-native.lua` only — no `generic.lua`, by design.**
Source: `source.lua`, bear 3.1.6. Tarball verified with `tar tf` (417
entries) before extraction.

## 1. Is it using the SYSTEM?

Yes. `$CMAKE_FLAGS` carries the install prefix and prefix path from
`packages/clang-native/generic.lua`; no hardcoded triplet/API/march, no
`export` of search flags, no `sed`/patch,
`cmake --build build --parallel 1` explicit.

## 2. Is it doing what the package needs?

**The blocker is real, structural, and stated honestly — I verified the
gRPC mechanism verbatim.** `third_party/grpc/CMakeLists.txt:1-45`:

```
pkg_check_modules(gRPC protobuf>=3.11 grpc++>=1.26)
if (gRPC_FOUND)
    … find_program(PROTOC protoc) … FATAL_ERROR if absent
    … find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin) … FATAL_ERROR if absent
    add_custom_target(grpc_dependency)
else ()
    include(ExternalProject)
    ExternalProject_Add(grpc_dependency
            GIT_REPOSITORY https://github.com/grpc/grpc
            GIT_TAG v1.49.2
            GIT_SUBMODULES GIT_SHALLOW 1
            …
```

Two facts make this unfixable here, and both are in the file:

1. **The fallback is a `git clone` at build time.** AGENTS.md: "No `jj`/`git`
   commands inside recipes; no network access at build time except `curl` in
   `source.lua` fetch blocks." An `ExternalProject_Add` with a
   `GIT_REPOSITORY` violates both clauses, and it happens during
   `cmake --build`, not configure.
2. **The preferred path needs something the prefix does not have.**
   `packages/protobuf` exists, but there is no gRPC anywhere in this tree, so
   `grpc++>=1.26` fails the `pkg_check_modules` and control falls to the
   clone.

There is no flag that disables the clone: the `if (gRPC_FOUND)` branch is the
only escape and it needs a real gRPC plus `protoc` plus `grpc_cpp_plugin`,
none of which this prefix has. I confirmed `packages/libiconv`-style absence
directly — there is no `packages/grpc` directory.

**Two provenance notes the recipe should know, neither a defect:**

- The Debian `bear_3.1.6.orig.tar.gz` unpacks as **`rizsotto-Bear-14c2e01/`**,
  not `bear-3.1.6/`. That is a *fork* tarball (rizsotto/Bear), not the
  canonical benchmark-action/bear. `CMakeLists.txt:5` does say
  `VERSION 3.1.6`, so the version is right, but `README.md` badges point at
  `rizsotto/Bear`. `--strip-components=1` handles the layout either way, and
  for a package that cannot build this is moot — but if bear is ever
  unblocked, the source should be revisited.
- There is a `rust/` directory in the tree. bear 3.x moved parts of itself to
  Rust, so a future unblock would need a cargo toolchain, not just gRPC.

**The two `--disable` flags are real and correctly justified.**
`CMakeLists.txt:15-16` defaults `ENABLE_UNIT_TESTS` and `ENABLE_FUNC_TESTS`
ON, and `:88-92` runs them with `TEST_BEFORE_INSTALL 1` — which *executes*
target binaries. That is the no-emulation wall, and both switches are
load-bearing on clang-native, which is a native (non-cross) build and therefore
would really run them. Confirmed against the source.

## The native-only shape — cross-cutting question 2

Same verdict as mold, and I confirmed it against the real loader: for
`bear@aarch64-android24`, `recipe_path` (`src/loader.lua:181-203`) finds
neither `bear/aarch64-android24.lua`, nor `bear/android.lua` (via that
system's `recipe_fallbacks`), nor `bear/generic.lua`, so `require` raises
`module 'bear@aarch64-android24' not found` — one clean line naming the exact
module. Well-formed, and a sensible error rather than a confusing one.

Is native-only substantively right? Yes, and more strongly than for mold. bear
is a **compiler adapter**: it `LD_PRELOAD`s an interposer onto the host
compiler/linker driver to capture the exact link command for later replay. A
cross-built bear could not intercept anything, and running one is forbidden
outright. The comment in `clang-native.lua` states this correctly.

**Is the blocker honestly recorded rather than papered over?** Yes, and this
is what I checked hardest. The recipe's comment names the mechanism
(`third_party/grpc/CMakeLists.txt:28-43`, the `ExternalProject_Add` git clone),
names what it tried first and why that fails, and says explicitly "There is no
flag that turns the clone off." It does not add a plausible-looking flag to
suppress the clone, and it does not claim the build might work. `stage1.md`
records all six rows as WILL NOT BUILD. That is exactly the behaviour AGENTS.md
asks for: record the blocker, do not fake a green, do not work around it in the
recipe.

## Is the recipe body itself coherent?

Yes, given the blocker. It is written in the shape the package *would* need —
`-DENABLE_UNIT_TESTS=OFF -DENABLE_FUNC_TESTS=OFF`, cmake with
`$CMAKE_FLAGS`, `cmake --install build` — so that when gRPC becomes available
the recipe is ready. The two switches it does pass are genuine options with the
stated defaults. No nonexistent flag.

## Forecast

I agree with **6 of 6**: all six rows are **WILL NOT BUILD**, including
clang-native.

That last one deserves emphasis because it is the row a careless reviewer might
upgrade to WILL BUILD ("it's native, cmake is there, the switches are
right"). No: the gRPC clone fires on clang-native too, because the blocker is a
missing *dependency*, not a cross-compilation problem. The adder did not
upgrade it, and I do not.

## Artifacts, had it built

`bin/bear` (the wrapper), `libexec/bear` (the compiled `bear` binary — bear
ships two: a shell wrapper and a compiled binary), and
`share/bear/*.conf`. All host binaries.

## Carried to the build

**Do not build this package.** The recipe is accepted as a correct record of a
blocker, not as a green build. `stage3.md` should record the blocker and the
verification, and should not present a partial build as progress.

```sh
# The blocker check, and it is the whole story for this package:
ls -d "$PACKAGEDIR/grpc" 2>/dev/null || echo "BLOCKED: no grpc package (required >= 1.26)"
# and the ExternalProject that would otherwise fire:
grep -n 'GIT_REPOSITORY\|ExternalProject_Add' \
     "$WORK/third_party/grpc/CMakeLists.txt" 2>/dev/null

# If it ever does build, the switches must have taken effect — otherwise the
# test targets RUN, which is the no-emulation wall:
grep -E '^(ENABLE_UNIT_TESTS|ENABLE_FUNC_TESTS):' "$WORK/build/CMakeCache.txt"
# expected: both OFF

# and the build log must contain no git clone at all:
grep -ciE 'git clone|Cloning into' "$WORK/build.log"   # expected 0

# artifacts, were it unblocked
test -x "$OUT/bin/bear" || echo "MISSING bin/bear"
test -x "$OUT/libexec/bear" || echo "MISSING libexec/bear"
$OBJDUMP -f "$OUT/libexec/bear" | head -3   # host machine, never a target
```