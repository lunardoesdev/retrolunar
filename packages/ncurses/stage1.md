# ncurses build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 6.6
- Build system: autotools (ncurses' own `configure`, not autoconf-generated
  from a modern `configure.ac` — it is a hand-maintained script, so the
  standard timestamp guard is applied but the flag vocabulary is ncurses')
- Installs: **shared** `libncursesw.so`, `libformw.so`, `libmenuw.so`,
  `libpanelw.so` plus their static counterparts, the headers, and five `.pc`
  files (`ncursesw.pc`, `formw.pc`, `menuw.pc`, `panelw.pc`, and a `tic`
  database). Then **nine compatibility symlinks** at `generic.lua:30-38`.
- Requires: `ncurses@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Two switches carry the design. `--with-shared` (with no `--without-shared`) builds the shared libraries **and** the static ones, which is deliberate: several recipes in this shard depend on a `-l` name that only the static archive satisfies cleanly. `--without-normal` builds only the **wide**-character (`w`) variants, halving the artifact set; the nine symlinks at `:19-27` then map the traditional non-wide names onto them, so a consumer that asks for `-lncurses` gets the wide library. That is a real design decision with a real cost — a consumer genuinely needing narrow ncurses cannot get it. `--enable-pc-files` is what produces the `.pc` files, and `--disable-stripping` keeps symbols for host-side inspection. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | ncurses' `configure` has its own Windows handling and `--with-shared` on a PE target produces `.dll` plus import libraries, which this tree has no consumer for. The open question is whether ncurses' `--with-termlib` default and its `tic`/terminfo build work under a PE cross build. What would settle it: whether the terminfo database is generated or whether configure reports a fallback. |
| clang-native | WILL BUILD | As above; native ncurses is unremarkable. |

**API level notes.** ncurses is exactly the kind of terminal library that
*could* be API-sensitive — it calls `ioctl`, `termios`, `read`/`write` on
file descriptors and, on some paths, `poll`. I checked the specific
`nl_langinfo` family that blocks `less` and `pkgconf`: ncurses uses it only in
`lib_termcap.c` behind `#ifdef HAVE_NL_LANGINFO`, and its own configure probes
for it, so it degrades rather than fails. **No API level gates this package.**
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The nine symlinks at `generic.lua:30-38` are the recipe's most
   consequential act and they mutate `$PREFIX`**, which persists and is shared.
   They are additive (`ln -sf`) and idempotent, and they exist because
   `less`'s `--with-termcap` probe asks for `-lncurses` — the `less` forecast
   in this shard names this exact dependency. So this recipe is load-bearing
   for `less` in a way the backlog does not record. **Do not remove them.**
2. **The `.pc` symlinks are the same idea for pkg-config**: `ncurses.pc`,
   `form.pc`, `menu.pc`, `panel.pc` point at the wide-character files. A
   consumer asking for `ncurses` gets a `.pc` that describes `libncursesw`.
   That is correct and intended, but it means `pkg-config --libs ncurses`
   silently gives you the wide library. Worth knowing before someone is
   surprised.
3. **`--with-shared` means this is one of the few packages in the tree
   producing versioned shared objects**, and the tree's stated position is that
   "a target prefix has no loader path for a versioned object"
   (AGENTS.md:248-250, the reason meson recipes pass
   `-Ddefault_library=static`). **This recipe contradicts that policy**, and
   unlike meson it has a static build too, so nothing breaks — but a reviewer
   should decide deliberately whether the `.so` is wanted. `topackage.md:61`
   records it as built without comment, so the decision appears never to have
   been made explicitly.
4. **The source version note is important and correct**: `source.lua:1-2`
   records that LFS pins `ncurses-6.5-20250809`, a dated patch release GNU no
   longer publishes, so the recipe uses the current stable. That is the same
   class of discovery as glog's missing assets and man-db's Savannah host, and
   it is properly commented. Keep it.
5. **`--disable-stripping` is a debugging choice, not a build necessity.** It
   keeps symbols so `$OBJDUMP`/`llvm-nm` work on the result, which this repo
   relies on. Fine, and arguably correct here, but it makes the shipped
   libraries larger.
6. **`make` at `:16` is not `make -j1`** — the usual rule deviation, and for
   ncurses it matters more than usual because the `tic` terminfo compiler is
   multi-stage.

**How to verify once built.**

- `lib/libncursesw.so` and `lib/libncursesw.a` both exist (the `--with-shared`
  claim); `lib/libformw.*`, `lib/libmenuw.*`, `lib/libpanelw.*` likewise.
- `include/ncursesw/curses.h` exists — note the `ncursesw` subdirectory, which
  is the wide-character layout.
- `lib/pkgconfig/ncursesw.pc` exists and `pkg-config --modversion ncursesw`
  reports 6.6.
- **The symlink check is the important one:**
  `ls -l lib/libncurses.so` must show a symlink to `libncursesw.so`, and
  `readlink lib/pkgconfig/ncurses.pc` must give `ncursesw.pc`. Missing
  symlinks break `less`.
- `ls lib/terminfo/` should be non-empty — that is the compiled terminfo
  database, and its absence would mean the `tic` step silently degraded.
- `file lib/libncursesw.so` reports
  `ELF 64-bit LSB shared object, ARM aarch64, for Android 24, built by NDK r28c`.
- `llvm-nm -D --defined-only lib/libncursesw.so | grep -cw 'tgetent\|setupterm'`
  non-zero.
