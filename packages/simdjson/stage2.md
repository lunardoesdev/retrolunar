ACCEPT

# simdjson 3.12.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/simdjson/`. I did not build.

**Adder A's finding #8 is CONFIRMED, and I verified it harder than it is
usually checked — by looking for the switch the recipe implies does not exist.**
In simdjson's top-level `CMakeLists.txt`:

```
line 307: add_subdirectory(tests)
line 308: add_subdirectory(examples)
line 310:   add_subdirectory(benchmark)     # inside if(CMAKE_SIZEOF_VOID_P EQUAL 8)
line 312: add_subdirectory(fuzz)
```

There is **no `SIMDJSON_JUST_LIBRARY` option** in this version, and no
`option(SIMDJSON_*)` guard around those four lines. So the recipe's comment —
"simdjson unconditionally adds its tests, examples, benchmark and fuzz
subdirectories on 64-bit hosts and **offers no option to turn them off**" — is
literally true, and `cmake --build build --target simdjson` is the *only*
available lever. Naming a target is a legitimate and ordinary way to build one
target of a larger project; it is not a patch and not a `sed`.

## What the recipe gets right

- `--target simdjson` limits the **build** to the library, and the comment is
  right that the install rules for the archive, the headers and the generated
  single-header all hang off that target — which is why `cmake --install build`
  afterwards still produces the right set.
- `-DBUILD_SHARED_LIBS=OFF` gives `libsimdjson.a`. `cmake --build build
  --target simdjson --parallel 1` is explicit about being serial even though the
  target is named, which is the correct combination.
- `./configure`'s absence is correct: simdjson is cmake, so there is no
  autotools guard to write. Nothing is hardcoded to a target, no flags are
  `export`ed, and `require("simdjson@source")` names no missing package.

## One unverified claim in the comment, and one residual risk worth naming

1. **The `-lrt` justification is not substantiated by the tree.** I grepped every
   `CMakeLists.txt` under `nest/source/simdjson` for `lrt` and found **no
   matches**. The comment's *primary* claim (no switch exists, so name the
   target) is verified and is the load-bearing one; the `-lrt` detail is
   plausible from older simdjson releases but unverified here. Worth rewording
   so the reason rests on what was actually checked:

```
        # Build only the library target. simdjson's top-level CMakeLists.txt
        # adds tests/ (line 307), examples/ (308), benchmark/ (310, on 64-bit)
        # and fuzz/ (312) unconditionally, and this version has no
        # SIMDJSON_JUST_LIBRARY option to suppress them - verified in the
        # 3.12.3 tree. Naming the target is therefore the only way to skip
        # those host programs; the install rules for the archive, the headers
        # and the generated single-header all hang off that target, so
        # 'cmake --install build' afterwards still produces the right set.
```

2. **The residual risk: those subdirectories are still *configured*.**
   `--target` limits what is built, not what is configured. `tests/`,
   `examples/` and `benchmark/` are `add_subdirectory`'d unconditionally, so
   their `CMakeLists.txt` files run at configure time — and `dependencies/`
   plus `tools/` are added even earlier (lines 291-292) to provide `cxxopts`.
   If any of those does a `find_package`, downloads, or otherwise fails at
   configure time, the build fails **before** `--target` has any effect. That is
   the one thing this recipe cannot defend against, and `stage1.md` should name
   it as the residual risk rather than leaving the impression that `--target`
   makes the host trees irrelevant. They are not configured-away, only
   unbuilt.

## Carried to the build

- `lib/libsimdjson.a` — `llvm-objdump -f lib/libsimdjson.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libsimdjson.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/simdjson.h`, `include/simdjsondom.h`, `include/simdjsonerror.h` — `[ -f include/simdjson.h ]` and `[ -f include/simdjsondom.h ]`.
- `include/simdjson.h` is the **single-header** build product (assembled by the `singleheader/` subdirectory into the amalgamated header). Confirm it is the amalgamated one, not a shim: `wc -l include/simdjson.h` should be in the tens of thousands.
- `lib/cmake/simdjson/simdjsonConfig.cmake` — `[ -f lib/cmake/simdjson/simdjsonConfig.cmake ]`.
- No `.pc` unless the release ships one; `pkg-config --modversion simdjson` may legitimately fail.
- **The check that settles this package:** no test, example, benchmark or fuzz binary may exist anywhere under `$OUT`. `find $OUT -name '*bench*' -o -name 'parse_number*'` should return nothing. Their presence means `--target simdjson` did not constrain the build.
- **And the check that would catch risk 2:** the configure log must show `tools/` and `dependencies/` being added and then not being built. If the configure step failed in either, the recipe's approach cannot help — that failure happens before any target is chosen.