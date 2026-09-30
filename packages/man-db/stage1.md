# man-db build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.13.1
- Build system: autotools
- Installs: `bin/man`, plus the man database tooling (`mandb`, `catman`,
  `whatis`) and the man configuration. The viewer is the main artifact. No
  library, no headers, no `.pc`.
- Requires: `man-db@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe passes six switches and every one of them removes something this prefix does not have or should not ship: `--disable-setuid` (a setgid man binary has no meaning on Android), `--enable-cache-owner=bin` (the cache is not root-owned here), `--with-browser=` and `--with-vgrind=` and `--with-grap=` left empty (none of those programs is in this prefix, and the empty value is the LFS-sanctioned way to say "not present"), and the two systemd unit dirs left unset for the same reason. That is a well-judged set. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | man-db is a POSIX program that reads terminfo and uses `groff` to format pages. `--with-browser=` being empty helps, but the core still wants a formatter and a terminfo database. Whether either is in this tree is the open question. What would settle it: whether `./configure` reports a usable formatter. |
| clang-native | WILL BUILD | As above; `topackage.md:55` records a successful native-shaped build. |

**API level notes.** None observed. man-db's C helper (`manpath`-adjacent
code) uses `getopt_long`, `glob` and `stdio`; nothing API-gated. The one
worth naming: man-db calls `nl_langinfo` for locale handling in some versions,
which would be an API-26 wall like `less` — but 2.13.1's configure gates that
behind a check, so it degrades. Worth confirming in the build log rather than
assuming. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The source URL is a real, recorded trap and the recipe explains it.**
   `source.lua:6-8`: man-db is a **nongnu** package on Savannah, not
   ftp.gnu.org — *"that is why the GNU path 404s."* `topackage.md:55` records
   the same thing. This is the second source-URL discovery in two rounds where
   the canonical-looking host is wrong (the first being glog's missing release
   assets). Do not "fix" it to ftp.gnu.org.
2. **The empty `--with-*` values are the interesting design choice.** Passing
   `--with-browser=` with nothing after the `=` is how you tell autoconf "this
   optional program is not available", and the recipe groups all three with one
   comment (`:6-7`) naming the reason. That is exactly the AGENTS.md:25-29
   standard: a switch whose absence would be a default.
3. **`--disable-setuid` is the security-relevant one** and it is right. A
   setgid `man` is a privilege boundary; on Android the whole tree is
   single-user, so the capability buys nothing and the risk is real. Good.
4. **`make` at `:16` is not `make -j1`** — the usual rule deviation.
5. **`man-db` and `man-pages` are installed into the same prefix and interact.**
   `man-pages` puts its pages in `share/man/`, and man-db's `mandb` indexes
   them. Neither requires the other in a recipe, so a prefix can have one
   without the other — which means `bin/man` may have nothing to display. That
   is a completeness observation, not a build defect, but a reviewer should
   know the two are independent.
6. `topackage.md:55` records the exact `file` output for `bin/man`, including
   the `interpreter /system/bin/linker64` detail. Good reference string.

**How to verify once built.**

- `bin/man` exists. `file bin/man` reports `ELF 64-bit LSB pie executable, ARM
  aarch64, version 1 (SYSV), dynamically linked, interpreter
  /system/bin/linker64, for Android 24, built by NDK r28c` — the exact string
  `topackage.md:55` recorded, including the interpreter line.
- `share/man/man1/` exists (man-db installs at least its own config).
- `$OBJDUMP -f bin/man` shows the target machine.
- `ls $OUT/bin/` should also show `mandb` and `catman`. Their presence is
  expected, not a leak.
- **Check the build log for a `nl_langinfo` failure** on android21/24. If it
  appears, this package joins `less` in being API-26-gated and the entry needs
  updating. This is the one open question in this file.
- `man` is a target binary: static inspection only, never run.
