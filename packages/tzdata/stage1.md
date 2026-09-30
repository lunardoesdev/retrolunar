# tzdata build forecast — BLOCKED: the release tarball is incomplete

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2025b (`data.iana.org/time-zones/releases/tzdata2025b.tar.gz`)
- Build system: **plain make** — `generic.lua:13` runs
  `make ZIC=zic TOPDIR="$OUT/usr" install`. No configure.
- Would install: `usr/share/zoneinfo/**` (TZif binaries), `usr/share/zoneinfo/iso3166.tab`,
  `usr/share/zoneinfo/zone.tab`, `usr/share/zoneinfo/tzdata.zi`, plus
  `usr/bin/tzselect`/`tzdata` symlinks.
- Requires: `tzdata@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | The release tarball is missing files its own Makefile requires. |
| aarch64-android24 | **WILL NOT BUILD** | Same; this is an upstream packaging defect, not a toolchain issue. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | **WILL NOT BUILD** | Same, plus the Makefile's POSIX assumptions. |
| clang-native | **WILL NOT BUILD** | **The blocker is not Android-specific at all** — it affects every system, which is unusual and worth stating plainly. |

**API level notes.** **None — and that is the finding.** `topackage.md:79`
records two separate problems, and neither is a Bionic symbol gate:

1. **The tarball is incomplete.** `Makefile:848` has
   `tzselect: tzselect.ksh version` and `Makefile:586` lists `tzselect.ksh`
   and `workman.sh`, but **neither file is in the IANA 2025b release tarball**.
   `make install` therefore stops with
   `No rule to make target 'tzselect.ksh', needed by 'tzselect'`. This is a
   class of upstream packaging defect the backlog elsewhere compares to GRUB
   2.14's missing `libgcrypt-grub/src/misc.c`, and it **cannot be fixed without
   adding files to the tarball** — which AGENTS.md forbids (no patches, no
   `sed`). So the recipe cannot be made to work by any legal means.

2. **A second, subtler wall the recipe *does* address.** Compiling the zones
   runs `zic`, and the Makefile's `ZIC` variable must point at a **host** `zic`.
   Left alone it would run the `./zic` it just built with the cross compiler —
   an aarch64 binary on this x86-64 host, which is exactly the emulated
   execution AGENTS.md:372-379 forbids. `generic.lua:6-13` fixes this exactly
   right: `make ZIC=zic` leaves `zic` to be resolved through `PATH` (the
   emitter puts `$NATIVE_PREFIX/bin` first, `AGENTS.md` "the generated
   script"), so the locally built target `zic` is never executed.

**That second workaround is good design and should be preserved** even if the
package stays blocked: it is the canonical example in this tree of the
no-emulation rule being honoured deliberately rather than by luck. If upstream
ever ships a complete tarball, the recipe should work as written.

**Risks / what a reviewer should check.**
1. **`ZIC=zic` depends on a host `zic` being on `PATH`.** On the Android
   systems that means `$NATIVE_PREFIX/bin/zic`, i.e. a `zic` built by
   `packages/tcl`? No — there is no `zic` package in `packages/` today. So
   this recipe currently has an **unmet implicit prerequisite**: it needs some
   native prefix to provide `zic`, and none in this tree does. A reviewer
   should decide whether to add a `zic` package or to accept the dependency.
2. **`source.lua:11` correctly omits `--strip-components=1`** — the IANA tarball
   has no top-level directory, and its comment says so. Worth preserving; a
   "consistency" edit that added the flag would break it.
3. Nothing here is compiled for the target except by `zic`, which is
   deliberately *not* the target one.

**How to verify once built.**
- `usr/share/zoneinfo/UTC`, `usr/share/zoneinfo/Europe/London`,
  `usr/share/zoneinfo/zone.tab`, `usr/share/zoneinfo/tzdata.zi`
- `file usr/share/zoneinfo/UTC` → `TZif2Data` version 2 or 3, then
  `version 2 '\0' 4 ...`
- **No `llvm-objdump` check applies** — zoneinfo files are data, not ELF. This
  is the only package in the shard where the architecture check is meaningless,
  and that is correct: the install is byte-identical on every system.
- To diagnose the blocker without a full build, check the tarball contents
  directly: `tar tzf dl/tzdata.tar.gz | grep -c 'tzselect.ksh'` → `0`.