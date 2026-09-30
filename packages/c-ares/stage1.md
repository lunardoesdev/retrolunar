# c-ares build forecast

- Recipe: `generic.lua`, source `source.lua` (release asset, ships a generated `configure`)
- Version pinned: 1.34.8
- Build system: autotools
- Installs: `lib/libcares.a` (static); `include/ares.h`, `include/ares_build.h`, `include/ares_version.h`; `lib/pkgconfig/libcares.pc`; **no tools installed** — `adig` and `ahost` (there is no `aadd`) are `noinst_PROGRAMS`: compiled as target programs, never installed
- Requires: `c-ares@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | c-ares' DNS resolver uses `getaddrinfo`, `getnameinfo`, `poll`, `fcntl`, `socket`, `sendmsg`/`recvmsg` and `res_ninit`-free paths. Bionic has all of these at API 21. Its resolver preference is `ares_getenv` + `getaddrinfo` on Android (`lib/ares_getenv.c`), which is exactly the right path here. Nothing references `nl_langinfo`, `getgrent`, `argp_parse`, `scandir` or `process_vm_readv`. `--disable-tests` is passed (`generic.lua:9`) and the comment gives the right reason: the tests need a network. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral. |
| x86_64-mingw | WILL BUILD | c-ares has a first-class Windows path (`lib/ares_syscfg.c`, winsock). Note that `generic.lua` does not disable the `adig`/`ahost`/`aadd` tools, so those get built too — see risks. |
| clang-native | WILL BUILD | Native; topackage.md:170 records c-ares 1.34.8 as `[x]` with `pkg-config --modversion libcares` = 1.34.8 and `elf64-littleaarch64` archive members. |

## API level notes

**21 is the floor and c-ares sits comfortably above it.** The one thing
worth naming is that c-ares does *not* use c-ares' own `res_*` code path
on Android — it detects Android in `configure` and prefers
`getaddrinfo`/`getnameinfo`, both of which are ancient in Bionic. There is
no API-level floor from the resolver.

## Risks / what a reviewer should check

- **The recipe comment claims "The tools (adig, ahost, aadd) are host
  programs and stay off"** (`generic.lua:7-8`) but the configure line
  (`generic.lua:9`) passes only `--disable-tests`. If c-ares' autotools
  builds the tools as `noinst_PROGRAMS`, they are compiled but not
  installed, and the comment is accurate in effect; if they are
  `bin_PROGRAMS`, they are installed too and the comment is wrong. I
  could not resolve this from the recipe alone. **This is the one claim in
  this file I am least sure of, and it is cheap to settle by listing
  `$OUT/bin` after a build.**
- **`--disable-tests` is load-bearing for a different reason than stated.**
  The comment cites the network, which is true, but c-ares' test suite
  also builds and runs a lot of target programs. Avoiding execution is the
  stronger reason under this repo's no-emulation rule.
- **Static + PIC is the prefix norm here** (`generic.lua:9`), consistent
  with `libevent` and `flac`.

## How to verify once built

- `lib/libcares.a`
- `include/ares.h`, `include/ares_build.h`
- `lib/pkgconfig/libcares.pc` and `pkg-config --modversion libcares` → `1.34.8`
- `readelf -h lib/libcares.a` → `Machine: AArch64` on Android targets
- `[ -x bin/adig ]` must FAIL — the tools are `noinst`; if they appear, the install picked up more than it should
