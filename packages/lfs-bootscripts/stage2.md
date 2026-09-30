ACCEPT

# lfs-bootscripts — stage 2 review

## What the recipe gets right

- **Pure data, single `cp -r`** at `generic.lua:7`. No compiler, no `make`, no
  flags, so no build-system rule can be violated.
- `$OUT/etc/` is the right destination for boot scripts.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## One thing to note, not a defect

`generic.lua:7` copies **everything** from the source tree with an unguarded
`cp -r *`, unlike `packages/iana-etc` which names its two files explicitly.
That is acceptable for a scripts-only package, but it means the installed set
is defined by whatever the tarball contains. The forecast should record the
expected file list so a future upstream re-tarball that adds a file is visible
in review rather than discovered at install time.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/etc/<the boot scripts>` | `ls $PREFIX/etc` — enumerate and compare against the forecast's list |
| no binaries | `find $PREFIX/etc -type f -exec file {} \; \| grep -c ELF` → 0, proving nothing executable slipped in |
