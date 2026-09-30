# iana-etc build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 20260911 (a release asset, `iana-etc-20260911.tar.gz`)
- Build system: none. Pure data.
- Installs: `etc/services` and `etc/protocols` — the IANA registry tables.
  Nothing is compiled, there is no library, no header and no `.pc`.
- Requires: `iana-etc@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:6-7` is a `mkdir` plus one `cp` of two text files. No compiler, no sysroot, no configure. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; the data is architecture-independent. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is byte-identical on every system and
there is no architecture check to make. The recipe says so at
`generic.lua:4`.

**API level notes.** None. The API level is not a variable for this package:
the recipe has no step that could observe it. `armv7a-android*` and
`i686-android*` match `aarch64-android*` exactly, and for the same reason.

**Risks / what a reviewer should check.**

1. **Install path is `$OUT/etc/`, i.e. `etc/` at the prefix root, not
   `share/`.** That is a deliberate LFS-style layout choice and it is correct
   for this prefix, but it means the published result is
   `$NESTDIR/<sys>/etc/services`, and `PKG_CONFIG_LIBDIR` never sees it. Not a
   bug — just worth knowing that the files are not in `share/`.
2. The recipe copies exactly two files by name. If upstream ever adds a third
   table (a new registry), the recipe silently omits it. A `cp` of the whole
   directory would be more robust but would also pull in whatever else the
   release tarball carries.
3. There is no `version` recorded in the installed files, so freshness comes
   only from the `.retrolunar-iana-etc` stamp versus the recipe file.

**How to verify once built.**

- `etc/services` and `etc/protocols` exist under `$NESTDIR/<sys>/`.
- `wc -l etc/services` is in the thousands (thousands of IANA service numbers);
  a zero- or few-line file means the copy silently failed.
- `head -1 etc/protocols` shows the upstream comment header, confirming it is
  the registry table and not an HTML error page.
- Compare the two copies: `cmp etc/services $NESTDIR/source/iana-etc/services`
  should be silent.
