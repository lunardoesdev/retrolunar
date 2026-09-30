# curl build forecast

- Recipe: `generic.lua` **and** `android.lua`, source `source.lua`
- Version pinned: 8.22.0
- Build system: autotools
- Installs: `lib/libcurl.a` (static); `include/curl/curl.h`, `include/curl/*.h`; `lib/pkgconfig/libcurl.pc`; **nothing else** — the recipe installs three targets only (`make -C lib install`, `make -C include install`, `make install-pkgconfigDATA`), so no `bin/`, no `curl-config`, no `lib/metalink/`
- Requires: `zlib` (exists, 1.3.1), `curl@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (with SSL)** | **This is the recorded, unresolved wall and it is exactly the "real `stderr` symbol" one.** The recipe comment (`generic.lua:7-8`) states it: "OpenSSL static archives reference stderr, which API 21 only provides as a macro (real symbol needs 23+); curl's configure probes fail to link. Stick to no-ssl until the floor moves." The recipe therefore passes `--without-ssl` (`generic.lua:9`), so **the library itself builds** — the row is WILL BUILD *as configured*, with TLS entirely absent. |
| aarch64-android24 | **WILL NOT BUILD (with SSL)** | Same at 24: the real `stderr` symbol arrives at API 23, so 24 should clear it — but the recipe does not branch on level (correctly, per AGENTS.md: one file per family), so `--without-ssl` still applies. The *capability* differs from 21; the *build* is identical. |
| aarch64-android35 | WILL BUILD | As configured (`--without-ssl`), will build. If the floor ever moved, removing `--without-ssl` would be the change to make. |
| x86_64-android35 | WILL BUILD | Same `stderr` reasoning; the recipe keeps `--without-ssl` for the whole Android family. |
| x86_64-mingw | **WILL NOT BUILD (with SSL), WILL BUILD as configured** | mingw has a real `stderr` in its CRT, so OpenSSL is not the obstacle there. The obstacle is different: `generic.lua:9` passes `--without-ssl` unconditionally, so mingw also gets a curl with no TLS, and mingw-w64's OpenSSL would need a different `--with-ssl` spelling. As configured it should link; the missing capability is TLS. |
| clang-native | WILL BUILD | glibc, and even `--without-ssl` links. topackage.md does not record curl as `[x]`, so this may be an unverified path — see risks. |

## API level notes

**The one API-level fact that matters here is `stderr`.** Bionic exposes
`stderr` as a macro at low API levels; the real symbol needs API 23+. The
Android systems already export `ac_cv_func_ffsl=yes` and
`gl_cv_func_strcasecmp_works=yes` (aarch64-android21/generic.lua:108-109)
for the *inline-function* class of problem, but `stderr` is a link-level
issue that no cache answer fixes — a static OpenSSL archive has an
undefined reference that the linker must resolve. So the workaround has to
be dropping the dependency, which is what the recipe does.

## Risks / what a reviewer should check

- **`--without-ssl` means this `libcurl.a` cannot do HTTPS.** For a package
  manager that downloads tarballs at *build* time this is tolerable (the
  fetch is `curl` from `/usr/bin`), but for a *consumer* of this prefix
  that wants HTTPS it is a real functional gap. The honest framing: the
  recipe documents it in a comment, and the readme should too.
- **The recipe is not in topackage.md as either `[x]` or blocked.** It
  simply is not on the LFS list, so there is no recorded verdict to
  contradict. But `packages/openssl` exists in this prefix, and the
  `stderr` wall means the two cannot be combined at API 21/24. That
  coupling is not written down anywhere except this file and the recipe
  comment. Worth surfacing.
- **`make -C lib install`, `make -C include install`,
  `make install-pkgconfigDATA`** (`generic.lua:16-18`) is a
  deliberately narrow install: it skips `bin/` and `docs/`. The recipe
  comment does not say so, and the "Installs" line in this file claims
  `bin/curl` is installed — **that claim is probably wrong.** The
  three targets named install the library, the headers and the `.pc`, and
  nothing else. I am flagging my own row as the uncertain part; `ls $OUT/bin`
  settles it in one command.
- **Everything else is off** (`--without-libpsl --without-libidn2
  --without-nghttp2 --without-nghttp3 --without-libssh2` and the protocol
  list, `generic.lua:9`). That is a large, deliberate feature reduction
  consistent with AGENTS.md's "smallest necessary set of flags", but it
  means the resulting `libcurl.a` supports only plain HTTP/FTP-less
  transfers.

## How to verify once built

- `lib/libcurl.a`
- `include/curl/curl.h`
- `lib/pkgconfig/libcurl.pc` and `pkg-config --modversion libcurl` → `8.22.0`
- `readelf -h lib/libcurl.a` → `Machine: AArch64`
- `readelf -s lib/libcurl.a | grep -i ssl` → **empty**, which is the check
  that the `--without-ssl` decision actually took effect
- `ls $OUT/bin` → settles whether `bin/curl` exists; my row above says
  probably not
