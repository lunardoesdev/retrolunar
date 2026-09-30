# libevent build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.1.12-stable (GitHub release asset)
- Build system: autotools
- Installs: static `libevent.a`, `libevent_core.a`, `libevent_extra.a`,
  `libevent_openssl.a`, the `event2/` headers, and `libevent.pc`,
  `libevent_core.pc`, `libevent_extra.pc`, `libevent_openssl.pc`. No sample
  programs, no regress suite, no benchmark.
- Requires: `openssl` (exists) — the only dependency, passed as
  `--enable-openssl` at `generic.lua:11`.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Three switches remove every host program: `--disable-samples` (the `sample/` tree is the bulk of what would otherwise link and run), `--disable-libevent-regress` (the test suite), and `--disable-benchmark`. What remains is the event core plus the OpenSSL backend, and OpenSSL is in the prefix. The timestamp guard at `:12-13` handles the tarball mtimes. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The compile should be fine — libevent's Windows support is its most heavily exercised path upstream. The open question is `--enable-openssl` finding this tree's OpenSSL, and libevent's `configure` probing for a working TLS backend. What would settle it: whether `configure` reports the openssl backend as found. A silently-disabled backend would still produce a working `libevent.a`, so the check matters. |
| clang-native | WILL BUILD | As above. |

**API level notes.** libevent's core is portable POSIX; the OpenSSL backend
adds no Bionic-gated symbol. The sample tree and benchmark are what would have
dragged in `posix_spawn` and friends, and all three are off.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The OpenSSL backend is a real cross-package link obligation.**
   `libevent_openssl.a` will carry undefined `SSL_*` symbols, and
   `libevent_openssl.pc` must name this tree's OpenSSL in its `Requires`.
   Check it. If it does not, the package builds and every consumer that wants
   TLS fails — the same latent class as lcms2 and libarchive.
2. **`--enable-openssl` is the only dependency-related switch, and there is no
   explicit `--with-openssl="$PREFIX"`.** libevent's configure finds OpenSSL
   through pkg-config, and the system `PKG_CONFIG_LIBDIR` points at `$PREFIX`
   first (`aarch64-android24/generic.lua:83-87`), so it should resolve to this
   tree's copy rather than anything in the sysroot. The comment at `:9-10`
   says exactly that. Worth confirming in the configure log, because a
   silently-different OpenSSL is the kind of mismatch that only shows up as a
   link error much later.
3. **libevent installs four separate `.pc` files**, one per library. That is
   upstream's layout and correct. A consumer wanting the full set should use
   `pkg-config --libs libevent` (the umbrella) rather than picking one.
4. `make -j1` is correct here (`:16`).
5. `topackage.md` records this as built: *"static libevent, libevent_core,
   libevent_extra and libevent_open[s]sl …"*, consistent with the four-target
   expectation above.

**How to verify once built.**

- `lib/libevent.a`, `lib/libevent_core.a`, `lib/libevent_extra.a` and
  `lib/libevent_openssl.a` all exist.
- `include/event2/event.h` exists.
- `pkg-config --modversion libevent` reports 2.1.12; the four `.pc` files all
  report the same version.
- `pkg-config --libs libevent_openssl` must mention openssl — otherwise the
  backend is unusable by consumers.
- `llvm-nm -u lib/libevent_openssl.a | grep -c SSL_` non-zero, proving the
  backend really compiled against OpenSSL rather than being stubbed out.
- `ls $OUT/bin/` must be empty (no samples, no regress, no benchmark).
