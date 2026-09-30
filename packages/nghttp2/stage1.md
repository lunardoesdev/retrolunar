# nghttp2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.68.0 (GitHub release asset, `.tar.xz`)
- Build system: autotools
- Installs: static `libnghttp2.a`, the `nghttp2/` headers, and `libnghttp2.pc`.
  **No applications** — no `nghttp`, `nghttpx`, `h2load`, no examples, no
  Python/Rust bindings.
- Requires: `nghttp2@source` only. No dependencies — and that is the point of
  the flag list.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | This is the most aggressive dependency-stripping recipe in the shard, and it is why the package works at all. `--disable-app` removes the `nghttp`/`nghttpx`/`h2load` family (a dozen host programs, several C++), `--disable-examples` and `--disable-tests` remove the rest of that, `--disable-python-bindings` and `--disable-rust-bindings` remove two cross-boundary toolchains, and then six `--without-*` flags remove every optional library: `--without-libxml2 --without-libevent-openssl --without-jansson --without-c-ares --without-libev --without-zlib` (`generic.lua:12`). What remains is the HTTP/2 framing and HPACK code, which needs nothing but libc. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The stripped library is portable C and would compile, but nghttp2's Windows support normally comes with Winsock and the recipe's switches say nothing about that. Whether the core builds without a socket layer depends on nghttp2's own `HAVE_WINSOCK` handling. What would settle it: whether `configure` succeeds and whether `libnghttp2.a` has a socket `connect` wrapper. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. nghttp2's core is buffer manipulation plus `read`
/`write` on a caller-supplied fd; the TLS layer is off entirely. No API-gated
symbol. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`--without-zlib` is worth a second look.** It strips the only
   compression-adjacent path, and nghttp2 normally uses zlib for the HPACK
   *static table* entropy coding. Without it, nghttp2 falls back to its own
   built-in coder, which is correct but slower on some inputs. This is a real
   trade (self-contained archive vs. throughput) rather than a defect, and the
   recipe's comment at `:10-11` says the prefix "keeps the core protocol and
   HPACK code dependency-free" — so it is deliberate and stated. Good.
2. **`--without-libxml2` is the same class of decision and is arguably more
   important**, because libxml2 is the package in this shard with its own
   Bionic problems (iconv, no separate `-liconv`). nghttp2 only uses it for
   the `nghttp` XML client, which is disabled anyway — so this switch is
   doubly redundant and harmless. Worth knowing so nobody re-enables it and
   drags libxml2's iconv wall back into this package.
3. **No `require()` at all is unusual and correct here.** Every other
   multi-capability package in this shard declares its dependencies; this one
   declares none because it uses none. A reviewer should confirm the archive
   really is libc-only: `llvm-nm -u lib/libnghttp2.a` should show no `xml*`,
   no `SSL_*`, no `Jan_*`, no `ares_*`, no `z_*` symbols.
4. **`--disable-app` is the switch that matters most.** Without it nghttp2
   builds `nghttp`, `nghttpx` and `h2load`, which are C++ programs that link
   the very libraries just disabled — so they would fail to link, or worse,
   pick up host copies. Correct to have off, and it is the difference between
   this package building and not.
5. `make -j1` is present (`:15`) — correct.
6. `topackage.md:173` records this as built: *"static libnghttp2.a;
   pkg-config --modversion libnghttp2 reports 1.68.0; archive members are
   elf64-littleaarch64. Applications, tests, bindings and every optional
   dependency off, so the library needs only libc."* **That entry is accurate
   and unusually precise** — it independently confirms the recipe's design and
   the libc-only conclusion. Not stale.

**How to verify once built.**

- `lib/libnghttp2.a` exists; `include/nghttp2/nghttp2.h` exists.
- `pkg-config --modversion libnghttp2` reports 1.68.0.
- `$OBJDUMP -f lib/libnghttp2.a` prints `elf64-littleaarch64` on Android — the
  exact check `topackage.md:173` already recorded.
- **The libc-only check is the one that matters:**
  `llvm-nm -u lib/libnghttp2.a | grep -cE 'xml|SSL_|Jan_|ares_|^ *U z_'` must
  be **0**. Anything else means a `--without-*` flag did not take.
- `llvm-nm --defined-only lib/libnghttp2.a | grep -cw nghttp2_session_init`
  non-zero.
- `ls $OUT/bin/` must be empty — no `nghttp`, no `nghttpx`, no `h2load`. Their
  presence means `--disable-app` regressed, and they would be target binaries
  that must never be run.
