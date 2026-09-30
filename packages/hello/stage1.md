# hello build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: none — `source.lua` has no `version` field, because there is
  no upstream. The "source" is a single `main.c` in `packages/hello/main.c`,
  copied verbatim by `source.lua`.
- Build system: none. One `$CC` invocation.
- Installs: `bin/hello`, a target executable. Nothing else.
- Requires: `hello@source` only. No package dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:7` is `$CC $CFLAGS main.c -o $OUT/bin/hello`. `$CC` is the API-level-carrying NDK wrapper (`aarch64-android24/generic.lua:42`) and `$CFLAGS` comes from the system (`:65`). If `main.c` calls only `printf`, which a hello-world does, there is no API-level dependency at all. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `$CFLAGS` is `-O2 -I$PREFIX/include` (`x86_64-mingw/generic.lua:12-15`). The output is a PE executable. |
| clang-native | WILL BUILD | As above; a native x86-64 ELF executable. |

**API level notes.** The only symbol a hello-world needs is `printf`, which
Bionic has at every API level. There is no `stderr`-as-symbol dependency, no
`mblen`/`getpass`, and no `posix_spawn`. This package exists as the minimal
end-to-end smoke test of the toolchain, so "it builds" is the whole claim.

**Risks / what a reviewer should check.**

1. This is not an upstream package, so the usual verification questions do not
   apply. What *is* worth checking is that it stays trivial: if someone adds a
   library call to `main.c`, the API-level sensitivity of the toolchain smoke
   test changes with it.
2. `source.lua` copies with `cp -rf $RECIPEDIR/main.c` and has no `dl/`
   guard, because there is no download. It relies on `main.c` being committed
   alongside the recipe. If that file goes missing, the failure is a `cp`
   error, not a 404.
3. No `.pc` file, no headers, no `lib/`. `$OUT/bin/hello` is the entire
   artifact.

**How to verify once built.**

- `bin/hello` exists under `$NESTDIR/<sys>/`.
- `file bin/hello` on an Android system reports
  `ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c`;
  on `x86_64-mingw` it reports `PE32+ executable`.
- `$OBJDUMP -f bin/hello` shows the target machine, proving the cross compiler
  was used rather than a host one.
- Do **not** run the binary. This package is a toolchain smoke test, and
  running an aarch64 binary on this x86-64 host is forbidden (AGENTS.md:373-379).
  Static inspection is the whole verification.
