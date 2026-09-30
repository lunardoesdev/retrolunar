# bc build forecast

- Recipe: `generic.lua` **and** `android.lua`, source `source.lua`
- Version pinned: 7.0.3
- Build system: **custom, hand-written configure** (GNU bc's own `configure`, not autoconf — this is why no timestamp guard appears in either recipe)
- Installs: `bin/bc`, `bin/bcgen`/`gen/bcgen` (the code generator), `bin/dc` (the `dc` symlink program); **no library, no `.pc`**
- Requires: `readline` (exists, 8.3), `bc@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD (with a noted gap) | `android.lua:11` is explicit that Android has no message catalog, so it passes `--disable-nls` plus `HOSTCC="cc"` for the host-side generator and `CC="$CC -std=c99"` for the target. C99 is the only real requirement and Bionic is C17 by default. **Gap worth naming:** with `--disable-nls` there is no `gettext`/`dcgettext` call, so no `nl_langinfo`; the readline link is supplied by `make LDFLAGS="$LDFLAGS -lreadline -ltermcap"` (`android.lua:13`), which is a recipe-local fix for a bug in bc's own custom configure (it omits termcap from the static readline link). |
| aarch64-android24 | WILL BUILD | Same reasoning; nothing in bc needs an API above 21. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same code path; `-lm` is already in the Android systems' `$LDFLAGS` (aarch64-android21/generic.lua:78). |
| x86_64-mingw | **UNCERTAIN** | `bc` 7.0.3's custom configure does detect `MINGW` and builds a `MINGW` console-mode `bc.exe`. The recipe passes no `--with-readline`-style switch beyond `--enable-readline`, so it links this prefix's readline — but that readline was itself built for `x86_64-w64-mingw32`, so the pairing is at least consistent. What I could not settle without building: whether bc's `expr.c`/`list.c` reference a termcap symbol that MinGW's readline spells differently. Flagged, not claimed. |
| clang-native | WILL BUILD | Native, and `generic.lua:10` is the plain form (no `HOSTCC`, no `--disable-nls`, because glibc has the catalogs). |

## API level notes

**API 21 is the floor and bc clears it.** The only Bionic-sensitive calls in
bc's sources are `gettext`/`dcgettext` (NLS) and readline; the first is
switched off explicitly for Android, the second comes from the prefix. No
`posix_spawn`, no `mblen`, no `getpass`, no `O_BINARY`, no `process_vm_readv`.
That is a deliberate, working wall-avoidance and it is the reason
`android.lua` exists for this package.

## Risks / what a reviewer should check

- **There is no autotools timestamp guard here, and there should not be.**
  bc ships a hand-written `configure`; running the AGENTS.md guard would
  fail on a missing `aclocal.m4`. Both recipes correctly omit it. Worth
  stating so a reviewer does not "fix" the omission.
- **`android.lua:12` passes `--prefix="$OUT"` itself** rather than using
  `$AUTOCONF_CONFIGURE_FLAGS`. That is right for a hand-written configure
  (AGENTS.md: this class of configure rejects `--host`/`--build`), but it
  is a place where a target fact could be hardcoded by accident. It is not
  currently.
- **The `make LDFLAGS=...` line overrides `$LDFLAGS` wholesale** rather than
  appending (`android.lua:13`, `generic.lua:12`). It re-expands `$LDFLAGS`
  so the system's search paths survive, which is correct — but a future
  edit that dropped the `$LDFLAGS` would silently lose `-L$PREFIX/lib`.
- **The mingw row is the open question.** It is UNCERTAIN, not "looks fine".

## How to verify once built

- `bin/bc`, `bin/dc`
- `file bin/bc` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android 21` on the oldest target
- `readelf -d bin/bc | grep NEEDED` shows `libreadline.so` or that it is
  statically linked — either is fine, but the binary must exist
- No library, no `.pc`; bc is a program
