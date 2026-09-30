# tcl-docs build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 8.6.18 (`sourceforge.net/.../tcl8.6.18-html.tar.gz/download`)
- Build system: **none — pure HTML data.** No configure, no compiler.
  `generic.lua:5-6` is one `mkdir` and one `cp`.
- Installs: `share/doc/tcl8.6.18/*.html`, `*.css`, `*.js`, `*.gif`,
  `http/` (the Tcl Library HTML manuals). **No library, no headers, no
  pkg-config file, no binaries.**
- Requires: `tcl-docs@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | One `mkdir` and one `cp`. Nothing reads a sysroot or invokes a compiler. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** Not applicable, by construction: nothing is compiled, so
there is no architecture check to perform and no way a target fact could leak
in. The installed tree is byte-identical on all six systems.

**Risks / what a reviewer should check.**
1. **Version skew with `packages/tcl` is deliberate and should stay visible.**
   This is 8.6.18 (`source.lua:2`); `packages/tcl/source.lua:2` pins the
   interpreter at **8.6.16**. `topackage.md:75` notes the same ("Tcl
   Documentation 8.6.18 (LFS 8.6.16…)"), so it is a known and accepted
   mismatch — the 8.6 series manuals are forward-compatible within the series.
   Worth a reviewer confirming they are comfortable with docs one patch release
   ahead of the interpreter, because it will look like a bug otherwise.
2. **The destination directory hardcodes the version** at `generic.lua:5`:
   `$OUT/share/doc/tcl8.6.18`. That is a *documentation path*, not a target
   fact, so it does not violate the no-hardcoded-target-facts rule — but it is
   a second place to update on a version bump (alongside `source.lua:2`), and
   unlike the interpreter there is nothing to keep it in sync automatically.
3. **`sourceforge.net/.../download` is a redirect-shaped URL**
   (`source.lua:6`). SourceForge mirrors can 302 to a region-specific host; if
   `curl -fSL` follows it (it does — `-L`), the fetch works but the URL is not
   a content-addressed one. No checksum is recorded, per the project's
   no-checksums decision.
4. **No `.pc`, no `bin/`, no `lib/*.a`** — correct, and worth verifying the
   *absence* of rather than hunting for artifacts that were never going to
   exist.
5. Like `systemd-man-pages`, these docs describe a facility (a Tcl
   interpreter) that may not be in the same prefix. That is fine — they are
   static files, and `packages/tcl` exists in this tree.

**How to verify once built.**
- `share/doc/tcl8.6.18/Tcl.html`, `share/doc/tcl8.6.18/TclTk.html`
- `ls share/doc/tcl8.6.18 | wc -l` should be a large count (the Tcl Library
  manuals are hundreds of files)
- `grep -c 'Tcl 8.6' share/doc/tcl8.6.18/Tcl.html` → non-zero, proving the
  expected documentation version landed
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**, the
  check that proves no toolchain got involved
- `cmp $NESTDIR/source/tcl-docs/Tcl.html share/doc/tcl8.6.18/Tcl.html` → exit 0
  for one file, proving the install is a faithful copy