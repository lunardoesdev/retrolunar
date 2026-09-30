# mpfr build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.2.2 (ftp.gnu.org, `.tar.xz`)
- Build system: autotools
- Installs: `libmpfr.a` and `mpfr.h`, plus the HTML documentation under
  `share/doc/mpfr-4.2.2/` (`make -j1 install-html` at `generic.lua:15`).
  No tools, no `.pc` of its own.
- Requires: `gmp` (exists) — a hard link dependency.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--enable-thread-safe` at `generic.lua:10` is the one meaningful switch: MPFR needs it for its thread-local exponent cache, and it is what makes the library safe to use from more than one thread. Everything else is arithmetic. No API-gated symbol. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; GMP is in the prefix. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. MPFR is a floating-point library on top of GMP
integers: it calls `mpz_*`, `malloc` and, for `mpfr_get_d` and friends, libc
math. `-lm` is already in every Android system's `LDFLAGS`
(`aarch64-android24/generic.lua:79`), so any `libm` dependency resolves
without a recipe change. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The same `--disable-static` problem as `mpc`, at `generic.lua:8`.**
   Autoconf's option is `--enable-static`; a bare `--disable-static` is not
   recognised and is ignored with a `configure: WARNING: unrecognized options`
   line. The build happens to be static because MPFR's default is static, so
   the recipe is correct **by accident**. This is now a confirmed pattern
   across two recipes (`mpfr/generic.lua:8` and `mpc/generic.lua:9`) and
   should be fixed once for both — either drop the flag or use the real
   `--enable-static --disable-shared` pair that libogg, libvorbis, jansson,
   libyaml and the rest of this shard use. **What would settle it: the
   configure log's `unrecognized options` warning.**
2. **`--docdir="$OUT/share/doc/mpfr-4.2.2"` duplicates the version**, once in
   `source.lua` and once in the path. A version bump must change both or the
   docs land in a directory named for a release that no longer exists. Same
   maintenance trap as `mpc/generic.lua:10` and lua's hand-written `.pc`.
3. **`make -j1 install-html` is required, not decorative.** MPFR's plain
   `install` does not install the HTML docs; `install-html` is a separate
   target. Simplifying it to `install` would silently lose them. Worth a
   comment.
4. **`--enable-thread-safe` is the one switch that changes the artifact's
   semantics**, and it is right to have it. On Bionic, `thread_local` works at
   every API level, so there is no per-level variation. A consumer that assumes
   MPFR is *not* thread-safe would now be wrong, but that is a correctness
   improvement, not a risk.
5. **GMP's own thread-safety is the other half of that**, and it is a real
   caveat: MPFR being thread-safe does not make GMP thread-safe. Worth a
   reviewer's note if any consumer in this tree uses both from multiple
   threads.
6. `topackage.md:60` records this as built with no caveats. Consistent.
7. `make -j1` throughout (`:13-15`) — correct.

**How to verify once built.**

- `lib/libmpfr.a` exists; `include/mpfr.h` exists.
- `share/doc/mpfr-4.2.2/index.html` exists, proving both `install-html` and
  `--docdir` took.
- `$OBJDUMP -f lib/libmpfr.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libmpfr.a | grep -cw mpfr_add` non-zero.
- `llvm-nm -u lib/libmpfr.a | grep -c 'mpz_'` must be non-zero, proving it
  links this tree's GMP.
- `grep -rn 'HAVE_THREAD\|thread_local' $PREFIX/include/mpfr.h` — the header
  should show the thread-local exponent declaration, which is the observable
  effect of `--enable-thread-safe`.
- **Check the configure log for `unrecognized options: --disable-static`** —
  that settles risk 1.
- `lib/libmpfr.so` should **not** exist; if it does, the ignored flag has
  stopped being harmless.
