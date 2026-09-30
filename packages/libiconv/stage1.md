# libiconv build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.18 (ftp.gnu.org)
- Build system: autotools
- Installs: static `libiconv.a`, `iconv.h`, `libiconv.la`'s installed
  `libiconv.pc`. No tools.
- Requires: `libiconv@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD (with a caveat) | `--disable-shared --enable-static --disable-nls` at `:7`. `--disable-nls` matters: libiconv's NLS support pulls in `libintl`/`gettext`, and `--enable-nls` is what would drag in a `libintl` that is neither in this prefix nor a Bionic concept. The library itself is portable C plus a large charset conversion table; no API-gated symbol. **The caveat is below** — read it before trusting the row. |
| aarch64-android24 | WILL BUILD (with a caveat) | As above. |
| aarch64-android35 | WILL BUILD (with a caveat) | As above. |
| x86_64-android35 | WILL BUILD (with a caveat) | As above. |
| x86_64-mingw | UNCERTAIN | Bionic's `iconv` situation does not apply, but GNU libiconv on Windows is unusual: its `configure` defaults to building for a DOS/Windows target and the `iconv()` vs `libiconv()` naming gets confusing. Whether this package is *wanted* at all on mingw — as opposed to whether it would build — is the real question. |
| clang-native | **Questionable** | glibc **already provides `iconv()`**, and GNU libiconv's `configure` is designed to notice and back off. On a glibc host this package may configure as a thin wrapper, install a `libiconv.a` that is largely a shim, or decline to install a library at all. That is not a failure so much as a package that has no purpose here. |

**API level notes.** I checked the NDK sysroot: `iconv_open` **is** present in
Bionic's `libc.a` (`llvm-nm` gives one match, and there is a `usr/include/iconv.h`).
Bionic has **no separate `-liconv`** — `iconv` lives in libc. This is the
crux of the libxml2 chain and it is worth stating plainly here, because
libiconv is the package that would otherwise fill that gap:

- On Android, a program links `iconv` from **libc**, not from a library.
- A `-liconv` on an Android link line would fail: no such file exists in any
  NDK sysroot.
- So **this package cannot solve libxml2's iconv problem on Android**, because
  the thing libxml2 needs is already in libc and the thing libiconv provides
  would be a second, conflicting implementation.

**Risks / what a reviewer should check.**

1. **The `python3.13`-style problem does not apply, but a real one does:
   libiconv is arguably redundant on every system in this tree.** On glibc and
   on Bionic alike, `iconv` is already in libc. This package would install a
   *second* `iconv()` that could conflict with the platform one at link time
   depending on search order. Before building it, someone should decide
   whether this prefix wants GNU libiconv's extra encodings (which glibc and
   Bionic both lack) or would rather use the platform's.
2. **`--disable-nls` is the load-bearing switch and it is correct.** libiconv's
   `gettext` integration is the one place this package could pick up an
   undeclared `libintl` dependency.
3. **`make` at `:11` is not `make -j1`** — the same rule deviation as kbd,
   less, kmod, libffi, intltool and others.
4. **No `.pc` guarantee.** libiconv 1.18's `Makefile.in` does install
   `libiconv.pc`, but its `Libs:` naming and `Libs.private` are worth checking,
   because this package exists precisely to be *linked against by* other
   things (libxml2 above all). A `.pc` that names the wrong library would be
   worse than none.
5. **`topackage.md` has no entry for this package** — I checked, and `libiconv`
   appears nowhere in the backlog. So this recipe exists without a recorded
   build or blocker. That is itself the finding: **it has never been built
   here**, and nothing in the tree currently requires it.

**How to verify once built.**

- `lib/libiconv.a` exists; `include/iconv.h` exists.
- `pkg-config --modversion libiconv` reports 1.18.
- `llvm-nm --defined-only lib/libiconv.a | grep -cw iconv_open` must be
  **non-zero**. If it is zero, configure decided the platform already had
  iconv and this package is a shim — which is the glibc outcome predicted
  above, and a reason to drop the package.
- `llvm-nm -u lib/libiconv.a | grep -c libintl` must be **0**, proving
  `--disable-nls` did its job.
- Check no `gettext`/`libintl` appears in the link: `pkg-config --static --libs
  libiconv` should name nothing but itself.
