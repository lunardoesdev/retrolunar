# man-pages build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 6.15 (mirrors.edge.kernel.org, the LFS pin)
- Build system: none. Pure data.
- Installs: `share/man/man1/`, `man3/`, `man5/`, `man7/`, `man8/` — pre-formatted
  roff manuals. No binaries of any kind.
- Requires: `man-pages@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:11-14` is a `mkdir` and a shell loop of `cp -r`. No compiler, no formatter, nothing executed. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; roff text is platform-independent. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make. The recipe says so at `:5`.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*` — the recipe has no step that could observe a level, and the
payload is text.

**Risks / what a reviewer should check.**

1. **The symlink loop at `generic.lua:12-14` is the whole recipe and it is
   correct, with a good reason recorded.** The tarball's top-level `man1`,
   `man3`, `man5`… entries are *symlinks into `man/`*. The rest of the prefix
   installs real `manN` directories (`man-db` does, and `m4` installs
   `share/man/man1/m4.1`). Copying the symlinks verbatim would therefore
   **collide with those real directories on publish**, when
   `cp -rf "$OUT"/. "$NESTDIR/<sys>/"/ merges. Iterating `man/*` and copying the
   *contents* out of `man/` sidesteps that. The comment at `:7-10` says
   exactly this. This is a real, subtle, already-diagnosed trap and the recipe
   handles it — a reviewer should confirm they understand *why* before touching
   it, because "simplifying" the loop to `cp -r *` would reintroduce a
   publish-time collision that is very hard to diagnose later.
2. **This is the second of three pure-data packages in the shard, and all
   three chose different install layouts** — `iana-etc` into `etc/`,
   `lfs-bootscripts` into `etc/`, this one into `share/man/`. The `share/man/`
   choice is the correct one (it is what `man-db` and `m4` also use) and the
   two `etc/` ones are LFS-legacy. Worth noting for consistency, not a defect.
3. **~2000 pages across five sections** according to `topackage.md:56`
   (man1 16, man3 1711, man5 158, man7 171, man8 11). That count is a useful
   regression check: a build that produces far fewer pages means the `man/`
   iteration missed something.
4. **These pages are Linux-specific.** On Android they document an OS that is
   not present. Staging them is harmless and they are useful as reference, but
   no target program will use them. Same category as `lfs-bootscripts`.
5. `topackage.md:56` records this as built with the exact per-section counts
   and the symlink observation. Consistent with this recipe.

**How to verify once built.**

- `share/man/man1/`, `man3/`, `man5/`, `man7/`, `man8/` all exist under
  `$NESTDIR/<sys>/`.
- Compare counts against `topackage.md:56`: man1 ≈ 16, man3 ≈ 1711, man5 ≈ 158,
  man7 ≈ 171, man8 ≈ 11. A sudden drop in man3 is the signal that the `man/`
  iteration broke.
- `find share/man -type l` must return **nothing**. Any symlink here means the
  recipe was changed to copy the top-level entries and a publish collision with
  `man-db`/`m4` is now latent. This is the single most important check.
- `head -1 share/man/man1/chmod.1` shows roff (`.TH`), confirming real content.
- `find share/man -type f | wc -l` should be in the low thousands.
