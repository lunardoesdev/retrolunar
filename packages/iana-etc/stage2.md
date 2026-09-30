ACCEPT

# iana-etc — stage 2 review

## What the recipe gets right

- **This is a pure-data package**: `generic.lua:6-7` copies exactly two files,
  `services` and `protocols`, into `$OUT/etc/`. No compiler, no `make`, no
  flags — so every build-system rule in `AGENTS.md` is satisfied vacuously.
- Both files exist in the unpacked tree, and the recipe names them exactly, so
  no glob can pick up the XML sources by accident.
- Version `20260911` is pinned with a `dl/` guard and `curl -C -`.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## One thing to note, not a defect

The forecast's own risk — a third upstream registry would be silently omitted
— is real and worth keeping. IANA adds registries over time, and a recipe that
copies two named files will quietly go stale without failing. If upstream ever
adds a registry this prefix needs, the recipe must be edited by hand; the
forecast should say that rather than implying the package tracks upstream
automatically.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/etc/services` | `test -s $PREFIX/etc/services` |
| `$PREFIX/etc/protocols` | `test -s $PREFIX/etc/protocols` |
| nothing else | `ls $PREFIX/etc` shows only these two plus whatever other packages add |
