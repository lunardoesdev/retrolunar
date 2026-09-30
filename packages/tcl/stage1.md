# tcl build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 8.6.16 (`downloads.sourceforge.net/tcl/tcl8.6.16-src.tar.gz`)
- Build system: **autotools**, but not at the top level — `generic.lua:8` runs
  `./unix/configure` from the source root
- Installs: `bin/tclsh8.6`, `bin/tclsh`, `lib/libtcl8.6.a`, `include/tcl8.6/*.h`,
  `lib/tcl8.6/**` (the `init.tcl` script library and `library/` packages),
  `share/man/mandoc` + gzipped man pages
- Requires: `tcl@source` only (`generic.lua:1`). No package dependencies —
  Tcl 8.6 is self-contained, threads are its own `libtclthread`, and the regex
  and zlib support are compiled in.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-rpath` (`generic.lua:8`) stops Tcl writing a `libtcl8.6.so`-style RPATH, which matters because Bionic's linker rejects host-style `-Wl,-rpath` in `$LDFLAGS` (`packages/x86_64-mingw/generic.lua:30` notes the analogous problem for PE/ELF). The core is `unix/tclUnixPipe.c`, `tclUnixChan.c`, `tclUnixDL.c` and `generic/tclParse.c`; they use `fork`/`execv` (in `tclUnixChan.c`, for `open |...`), `mmap`, `dlopen`-equivalent `Tcl_LoadFile` via `TclpLoadFile` on Bionic's `libdl` stub, and `sigaction`. **All of those exist at API 21.** No `mktime_z`, no `nl_langinfo`, no `posix_spawn` — `posix_spawn` was the obvious risk for `open |...` and Tcl does not use it. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; Tcl has no arch-specific code. |
| x86_64-mingw | WILL BUILD | `unix/Makefile.in` has a Win32 branch (`TCL_WINDOWS`); `--host=x86_64-w64-mingw32` selects it. |
| clang-native | WILL BUILD | Native. |

**API level notes.** **No new wall, and this one is worth stating carefully
because Tcl is old code that touches a lot of process machinery.** The
specific traps I checked and cleared: Tcl 8.6 is C89-era but declares its own
prototypes, so there is no implicit-declaration problem under the NDK's default
C23; it does not use `nl_langinfo` (API 26) or `iconv.h` (API 28) — its
encoding conversion is its own `Tcl_ExternalToUtfDString` table, not libc's;
and it does not use `mktime_z` (API 35). The API level is inert for this
package.

**Risks / what a reviewer should check.**
1. **`./unix/configure` is run from the source root** (`generic.lua:8`), not
   from `unix/`. The comment at `generic.lua:6-7` says Tcl's configure accepts
   this and the build then happens in that directory. This is a genuine
   deviation from the usual pattern and worth a second look, because it is the
   kind of thing that works for Tcl specifically and would not generalise.
   Tcl's configure is hand-maintained (not autoconf-generated), which is also
   why **no autotools timestamp guard is needed or present** — correct, since
   there is no `aclocal.m4`/`config.h.in` pair to touch.
2. **`--mandir="$OUT/share/man"` is passed explicitly** (`:8`) because Tcl's
   configure derives the man page path from `--libdir` and would otherwise put
   them somewhere the nest does not publish. Overriding a target path on the
   make/configure line is legitimate — it is about the *install layout*, not the
   target machine.
3. **`make install-private-headers` is a separate third invocation**
   (`generic.lua:12`). Tcl splits public and private headers, and anything
   building a Tcl extension needs the private ones; this is deliberate and
   correct, not a leftover. A reviewer should check that it did not fail
   silently — a Tcl extension consumer depends on it.
4. `make -j1` is explicit at `:9-11`, satisfying AGENTS.md's serial-build rule.
5. **Tcl's `exec` uses `fork`+`execv`, which works at API 21**; this is
   recorded above because "Tcl forks" sounded like a plausible API-24 wall and
   is not one.

**How to verify once built.**
- `bin/tclsh8.6`, `lib/libtcl8.6.a`, `include/tcl8.6/tcl.h`,
  `lib/tcl8.6/init.tcl`
- `llvm-objdump -f lib/libtcl8.6.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libtcl8.6.a | grep -c Tcl_CreateInterp` → non-zero
- `strings lib/tcl8.6/init.tcl | grep -m1 '8.6'` for the version stamp
- `find $PREFIX/include/tcl8.6 -name 'tclInt.h'` → **must be present**; that is
  the check that `make install-private-headers` did its job
- `file bin/tclsh8.6` → `ELF 64-bit LSB pie executable, ARM aarch64`. The
  binary cannot be executed (no emulation); a smoke test would need a target
  device.