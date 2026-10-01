# LFS packages to add or update

Checklist based on the [Linux From Scratch 12.4, Chapter 3.2: All Packages](https://www.linuxfromscratch.org/lfs/view/stable/chapter03/packages.html). Versions below are the versions listed by that book. Python (including its documentation tarball) and the Linux kernel are intentionally excluded; other supporting source/data tarballs listed by LFS are included.

Packages already in this repository remain on this list as candidates for version or build-script updates. Do not filter the list to only packages that are currently missing.

- [x] Acl 2.3.2
- [x] Attr 2.5.2
- [x] Autoconf 2.72
- [x] Automake 1.18.1
- [ ] Bash 5.3 (Android 24 blocked: getgrent requires API 26)
- [x] Bc 7.0.3
- [x] Binutils 2.45 (gprofng disabled; Android 24 lacks pthread cancellation APIs)
- [x] Bison 3.8.2
- [x] Bzip2 1.0.8
- [x] Coreutils 9.7
- [x] DejaGNU 1.6.3
- [ ] Diffutils 3.12 (blocked: src/system.h needs <stdbit.h>, absent in the NDK)
- [ ] E2fsprogs 1.47.3 (blocked: upstream tarball URLs return 404)
- [ ] Elfutils 0.193 (blocked: CONFIRMED by build on aarch64-android24 - and not buildable on Bionic at any API level. configure.ac:651 is AC_SEARCH_LIBS([argp_parse], [argp]) and :654 is AC_MSG_FAILURE([failed to find argp_parse]), inside an unconditional top-level block (:650-658, no AS_IF and no switch), so ./configure aborts before AC_OUTPUT ever runs and neither config.h nor Makefile is generated. argp_parse is a glibc extension; argp.h is absent from the entire NDK r28b sysroot, and unlike nl_langinfo (API 26) or posix_spawn (API 28) it carries no __INTRODUCED_IN gate, so no new aarch64-androidNN target helps. All 47 --enable/--disable/--with/--without options in ./configure --help were enumerated and none drops libdw, libdwfl, libstack, libebl or tests/ from the unconditional SUBDIRS at Makefile.am:31-32. Pre-setting the cache variable is not a fix either: the macro is AC_SEARCH_LIBS so the variable is ac_cv_search_argp_parse (the AC_CHECK_LIB spelling is ignored), =no re-triggers the same failure, any other value only moves it to the fts_close (:661/:664) and _obstack_free (:671/:674) probes immediately behind it, and only after answering all three does it become a link-time failure via argp_LDADD in libdw/Makefile.am:112. The only real routes are an upstream patch to configure.ac:650-658 or a stub libargp, both forbidden by the no-patch rule. Never built on clang-native either - no stamp and no artifact in nest/clang-native - so stage1.md keeps that row UNCERTAIN. Build log in packages/elfutils/stage3.md)
- [x] Expat 2.7.1
- [ ] Expect 5.45.4 (blocked: bundled tclconfig/config.sub has no aarch64 support)
- [ ] File 5.46 (blocked: magic.mgc needs file 5.46 on the build host)
- [ ] Findutils 4.10.0 (blocked: needs mktime_z, Bionic exposes it at API 35)
- [ ] Flex 2.6.4 (blocked: cross build selects an incomplete realloc replacement)
- [x] Flit-core 3.12.0 (module only; no dist-info without host pip)
- [ ] Gawk 5.3.2 (blocked: needs nl_langinfo, Bionic exposes it at API 26)
- [ ] GCC 15.2.0 (blocked: LFS builds it in three cross-bootstrap passes; one package = one build here)
- [x] GDBM 1.26
- [ ] Gettext 0.26 (blocked: NDK hides iconv.h before API 28, so libtextstyle is built with HAVE_ICONV=0 and libtextstyle/lib/libtextstyle.sym.in:41 still exports iconv_ostream_create; ld.lld: version script assignment of 'global' to symbol 'iconv_ostream_create' failed: symbol not defined)
- [ ] Glibc 2.42 (blocked: it is a libc; the NDK sysroot is bionic and has no glibc cross sysroot)
- [x] GMP 6.3.0
- [x] Gperf 3.3
- [x] Grep 3.12
- [ ] Groff 1.24.2 (LFS 1.23.0; latest stable; blocked: doc/doc.am:392 renders doc/webpage.ps with the just-built groff (Makefile.am:497 GROFFBIN), and make install wants that file, so the build cannot finish without executing an aarch64 binary on the x86_64 host)
- [ ] GRUB 2.14 (LFS 2.12; latest stable; blocked: 2.14 tarball omits grub-core/lib/libgcrypt-grub/src/misc.c and defines no `gcry` module to compile it, so the new pubkey module's rsa-common.c references _gcry_log_printmpi, which no module defines; grub-core/Makefile:57254 moddep.lst then fails with "_gcry_log_printmpi in pubkey is not defined". Not fixable without patching upstream sources)
- [x] Gzip 1.15 (LFS 1.14; latest stable)
- [x] Iana-Etc 20260911 (LFS 20250807; latest stable; data only, no binaries)
- [ ] Inetutils 2.8 (LFS 2.6; latest stable. Mostly builds: telnet/telnet links and is a real Android 24 aarch64 binary ("ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c"), after forcing <termios.h> for telnet/sys_bsd.c, which uses struct termios without including it (glibc pulls it in transitively, Bionic does not). BLOCKED on ifconfig: changeif.c:256 calls ether_hostton, and Bionic has neither that symbol (llvm-nm on libc.so shows only ether_aton/ether_aton_r/ether_ntoa/ether_ntoa_r) nor a header declaring it - glibc declares it in <netether.h>. Supplying it would mean patching upstream or shipping a shim, both forbidden)
- [ ] Intltool 0.51.0 (blocked: configure hard-requires the XML::Parser Perl module - "configure: error: XML::Parser perl module is required for intltool" - and no perl on this host has it, neither /usr/bin/perl 5.42.2 nor the nest's native perl 5.44.0. XML::Parser is itself blocked in this backlog. Note upstream's own download URL that LFS cites, launchpad.net/intltool/trunk/0.51.0, now returns a 502 and download.gnome.org only carries releases to 0.40, so the recipe fetches the unmodified 0.51.0 release tarball from Debian's pool mirror)
- [ ] IPRoute2 7.2.0 (LFS 6.16.0; latest stable. blocked: its configure probes libmnl unconditionally - the have_mnl_attr_get_uint test at configure:371 compiles against <libmnl/libmnl.h> and links via `pkg-config libmnl` (configure:379) - and libmnl is neither in the prefix nor anywhere in this backlog. libcap, libelf and libbpf are also absent; libcap and elfutils are backlog entries but libmnl is not, so this cannot be satisfied from the current package set)
- [x] Jinja2 3.1.6 (matches LFS pin; pure Python, module only, no dist-info)
- [ ] Kbd 2.10.0 (LFS 2.8.0; latest stable. blocked: src/libcommon/error.c:18 and :35 use program_invocation_short_name, a glibc-ism that Bionic neither declares in any NDK header nor exports from libc.so (llvm-nm finds zero matches). It is a GNU extension surfaced by errno.h under __USE_GNU, so the only fix is to define it from argv[0] in the upstream source, which the no-patch rule forbids. Note resizecons needs no workaround here: configure sets RESIZECONS_PROGS=no for any non-i386/x86_64 target at configure.ac:155, so LFS's sed step is unnecessary)
- [ ] Kmod 34 (blocked: two glibc-isms that Bionic does not provide, with no meson fallback check. shared/util.c:383 calls get_current_dir_name and libkmod/libkmod-index.c:224 calls fread_unlocked; llvm-nm on Bionic's libc.so finds neither symbol and no NDK header declares them. kmod's meson.build has no HAVE_ test or -D option to avoid them, so the only fix is guarding those call sites in the upstream source, which the no-patch rule forbids. Note Meson 1.12.1 was added to the prefix as its prerequisite, and kmod itself is fetched from the v34 git tag because kernel.org carries no kmod release tarball)
- [ ] Less 685 (LFS 679; latest stable. blocked: charset.c:432 calls nl_langinfo, which Bionic declares only inside __BIONIC_AVAILABILITY_GUARD(26) as __INTRODUCED_IN(26) in langinfo.h:97, so it is not declared at API 24. Same root cause that already blocks Gawk and Pkgconf in this backlog; the only fixes are raising the target API level or patching the call site, both out of scope here)
- [x] LFS-Bootscripts 20250827 (matches LFS pin; data only, no binaries)
- [ ] Libcap 2.78 (NOT blocked by an unreachable source — that blocker was wrong. The research probed `pub/linux/libs/libcap` with a `.tar.gz` extension; the real tarball is `.tar.xz` under a different path, `pub/linux/libs/security/linux-privs/libcap2/`. Verified reachable: `curl -I` on https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.78.tar.xz returns HTTP/2 200, content-type application/x-xz, content-length 201040. The recipe already uses that URL. Still unchecked because it has never been built here, and the version moves 2.76 -> 2.78 to match what the recipe pins)
- [x] Libffi 3.8.0 (LFS 3.5.2; latest stable. libffi.so is "ELF 64-bit LSB shared object, ARM aarch64, for Android 24, built by NDK r28c"; static members are elf64-littleaarch64; pkg-config --modversion libffi reports 3.8.0)
- [x] Libpipeline 1.5.8 (matches LFS pin. libpipeline.so is "ELF 64-bit LSB shared object, ARM aarch64, for Android 24, built by NDK r28c"; pkg-config --modversion libpipeline reports 1.5.8. Note rctg.com now serves a parked-domain page, so the recipe uses the canonical download.savannah.gnu.org URL that LFS cites)
- [ ] Libtool 2.5.4 (matches LFS pin. blocked: doc/libtool.1 is built by help2man, which is not present on this host, and libtool's configure offers no flag to skip the manual - --disable-ltdl-install and --disable-shared are the only relevant ones. The autotools side did get sorted out: this recipe's timestamp guard has to touch config.status and libtool after aclocal.m4, otherwise config.status --recheck re-runs configure and resets the timestamps, which sends make looking for aclocal-1.17 that the prefix does not have. help2man is a perl script and could be supplied as a native package, but adding one is out of scope for this list)
- [ ] Libxcrypt 4.5.2 (LFS 4.4.38; latest stable, from the besser82/libxcrypt fork the LFS page names; bminor/libxcrypt 404s for every release tarball. TWO stages, both now diagnosed. (1) SOLVED: the original failure was the native perl's unusable @INC, now fixed - see the perl 5.44.0 entry - so configure and its perl helpers run cleanly. (2) remaining upstream defect: linking libcrypt.la fails with "ld.lld: error: version script assignment of 'XCRYPT_2.0' to symbol 'xcrypt' failed: symbol not defined", and likewise for crypt_gensalt_r, xcrypt_gensalt and xcrypt_gensalt_r. The version script is generated by build-aux/scripts/gen-libcrypt-map from lib/libcrypt.map.in, which lists those five symbols only when a compatibility ABI is selected, but the 4.5.2 tarball contains no lib/xcrypt.c at all, so those symbols can never be defined. Passing --enable-obsolete-api=glibc does not help: configure.ac:443-456 force-disables the obsolete APIs unless descrypt is among the enabled hashes, and adding descrypt leaves COMPAT_ABI=glibc so the map still lists symbols with no implementation. Fixing it needs an upstream change, which the no-patch rule forbids)
- [x] Lz4 1.10.0 (matches LFS pin. bin/lz4 is "ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c"; lib/liblz4.a members are elf64-littleaarch64; bin/lz4c also installed)
- [x] M4 1.4.20
- [x] Make 4.4.1 (matches LFS pin. bin/make is "ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c")
- [x] Man-DB 2.13.1 (matches LFS pin, and is the newest in the release directory. bin/man is "ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 24, built by NDK r28c". Note it is a nongnu package hosted on Savannah, NOT on ftp.gnu.org - that is why the GNU path 404s; the recipe fetches download.savannah.gnu.org/releases/man-db/, the URL LFS itself cites)
- [x] Man-pages 6.15 (matches LFS pin; data only, no binaries. Installed under share/man/man/ - man1 16, man3 1711, man5 158, man7 171, man8 11 pages. The tarball's top-level man1/man3/... entries are symlinks into man/, so only man/ is copied)
- [x] MarkupSafe 3.0.3 (LFS 3.0.2; latest stable; pure Python, no dist-info. The optional _speedups C accelerator is NOT compiled - _speedups.c ships as source but no .so is produced - so the module uses its _native.py fallback)
- [x] Meson 1.12.1 (LFS 1.8.3; latest stable; pure Python, module + bin/meson launcher, no dist-info)
- [x] MPC 1.3.1
- [x] MPFR 4.2.2
- [x] Ncurses 6.6 (LFS 6.5-20250809 tarball returns 404; current stable used)
- [ ] Ninja 1.13.2 (blocked: Android 24 NDK hides posix_spawn APIs introduced in API 28)
- [x] OpenSSL 4.0.2 (LFS 3.5.2; latest stable release)
- [x] Packaging 26.3 (LFS 25.0; latest stable; module only, no dist-info)
- [x] Patch 2.8
- [x] Perl 5.44.0 (latest stable; built for the NATIVE clang-native system as a static x86-64 perl, which is what a native package is supposed to be. A TARGET aarch64-android perl is still blocked: upstream's Android cross-build requires a reachable adb/ssh device, and none is available. The module search paths are configured with -Dprivlib/-Darchlib/-Dsitelib/... pointing at $PREFIX rather than the $OUT staging dir, because perl bakes those absolute paths in with no relocation support; verified that the installed perl then finds ExtUtils::MakeMaker and runs xsubpp with NO PERL5LIB set, which was not true before)
- [ ] Pkgconf 3.0.7 (blocked: Bionic introduced nl_langinfo in API 26; API24 compilation fails)
- [ ] Procps 4.0.7 (blocked: Clang 19 rejects FLT_MIN token-pasting in src/ps/common.h:101)
- [ ] Psmisc 23.7 (blocked: Android cross link leaves rpl_malloc and rpl_realloc undefined)
- [x] Readline 8.3
- [x] Sed 4.10 (LFS 4.9; latest stable)
- [x] Setuptools 84.0.0 (LFS 80.9.0; latest stable)
- [ ] Shadow 4.20.3 (blocked: Android Bionic lacks shadow.h required by configure)
- [ ] Sysklogd 2.7.2 (blocked: Bionic exposes getsubopt at __INTRODUCED_IN(26), so API 21, 23 and 24 all fail to compile logger — the gate is 26, not 24, so an earlier version of this line named API 24 as the failing one and sent a reader looking for an android25 target that does not exist. Recoverable: the android26 and android35 targets in this tree are both ≥ 26, and neither needs a recipe change)
- [ ] Systemd 262 (LFS 257.8; blocked: upstream requires glibc >=2.34 or musl >=1.2.6, not Bionic)
- [x] Systemd Man Pages 262 (LFS 257.8; latest systemd release)
- [ ] SysVinit 3.14 (blocked: Android NDK sysroot lacks sys/kd.h required by init.c)
- [ ] Tar 1.35 (blocked: Bionic guards mktime_z until API 35; target API24 cannot compile it)
- [x] Tcl 8.6.16
- [x] Tcl Documentation 8.6.18 (LFS 8.6.16; latest 8.6 maintenance docs)
- [ ] Texinfo 7.3 (LFS 7.2. UNTESTED. An earlier version of this line recorded a blocker — "nested tta configure falls back to cc and cannot create executables" — which no longer describes the recipe: that was the recipe's own fault and has been corrected, so the recorded reason no longer matches anything a builder would hit. The honest state is that the mitigations have landed but nothing has been built since, so neither the old blocker nor a new pass can be claimed. Keep it unchecked until a build on a target system says otherwise)
- [ ] Time Zone Data 2025b (blocked: the IANA 2025b release tarball omits files its own Makefile requires. Makefile:848 has `tzselect: tzselect.ksh version` and Makefile:586 lists tzselect.ksh and workman.sh, but neither file is in the tarball, so make stops with "No rule to make target 'tzselect.ksh', needed by 'tzselect'". This is the same class of upstream packaging defect as GRUB 2.14's missing libgcrypt-grub/src/misc.c, and it cannot be fixed without adding files to the tarball. Separately worth recording: compiling the zones runs zic, and the Makefile's ZIC variable must be pointed at the host zic via PATH, because otherwise it would run the ./zic it just built with the cross compiler, i.e. an aarch64 binary on this x86_64 host)
- [x] Udev-lfs Tarball udev-lfs-20230818 (matches LFS pin; data only, no binaries. 55-lfs.rules installed to lib/udev/rules.d/, the write_cd_rules/write_net_rules generators to usr/share/udev/, docs to usr/share/doc/udev-20230818/. Its own Makefile.lfs is not used because it installs from a versioned subdirectory that the flat release tarball does not have)
- [ ] Util-linux 2.42.4 (LFS 2.41.1; latest stable, from mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/ - the v2.41.1 path I first tried 404s because upstream lays these out per minor version, not per patch. blocked: libmount/src/tab_parse.c:893 calls scandirat(..., versionsort) and versionsort is a glibc extension that Bionic neither declares in any NDK header nor exports from libc.so (llvm-nm: zero matches); util-linux bundles no replacement and the call is not behind any #if, so libmount cannot compile. The recipe does get past two other walls and those fixes are kept: --without-cap-ng (libcap is absent and has no reachable source), --disable-asciidoc, and --disable-more/--disable-vipw for the same _PATH_VI glibc-ism Bionic lacks. There IS an upstream --disable-libmount/--disable-libblkid pair that would compile, but that would remove lsblk, findmnt, blkid and much of df and mount, which is a scoping decision rather than a build fix, so it was not taken unilaterally)
- [x] Vim 9.2.1143 (LFS 9.1.1629; latest stable 9.2 series. bin/vim is "ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 24, built by NDK r28c", stripped. Fetched from the v9.2.1143 git tag because the archive ships a prebuilt src/configure. Deviation: LFS appends a SYS_VIMRC_FILE define to src/feature.h to move the vimrc to /etc, but that edits an upstream source, so the default prefix location is kept)
- [x] Wheel 0.48.0 (LFS 0.46.1; latest stable; module only, no dist-info)
- [ ] XML::Parser 2.47 (blocked, and NOT for the reason first recorded. A native perl running Makefile.PL is the correct XS cross-build mechanism and perl@native now exists, but upstream's own Makefile.PL cannot complete cross: its Devel::CheckLib probe is not cross-aware. _findcc (inc/Devel/CheckLib.pm:459) reads only $Config{cc} and ignores $ENV{CC}, so the probe compiles with the native perl's x86-64 clang and fails to link the aarch64 libexpat.a ("libexpat.a(xmlparse.c.o) is incompatible with elf64-x86-64"). Forcing $Config{cc} to the cross wrapper instead makes the probe link, but assert_lib then EXECUTES it (inc/Devel/CheckLib.pm:404), which needs an aarch64 binary to run on this x86-64 host - forbidden here, and the host has qemu-aarch64 registered in binfmt_misc. not_execute=>1 is not passed by Makefile.PL and PERL_MM_OPT does not reach check_lib. The XS compile itself is fine: xsubpp output builds to "ELF 64-bit LSB relocatable, ARM aarch64" once Bionic's libc-only feature macros are handled. Fixing this needs an upstream Makefile.PL change, which the no-patch rule forbids)
- [x] Xz Utils 5.8.1 (matches LFS pin, version unchanged. bin/xz is "ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 24, built by NDK r28c" and the library is now lib/liblzma.a rather than a shared object — the recipe passes --disable-shared, added as a deliberate policy correction so xz is not the one package out of ~150 still shipping a shared object, and every consumer here reaches it through pkg-config and links the archive. The liblzma.so this line used to record no longer exists. pkg-config --modversion liblzma reports 5.8.1. NLS and the unxz/lzmadec/lzmainfo helpers and scripts are off)
- [x] Zlib 1.3.1
- [x] Zstd 1.5.7 (matches LFS pin. bin/zstd is "ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c"; lib/libzstd.a members are elf64-littleaarch64; pkg-config --modversion libzstd reports 1.5.7, which also unblocks Kmod's zstd compression backend)


# Popular C/C++ development packages (candidates)

Three curated lists of C/C++ developer-facing packages, one per platform, to
work through after the LFS list above. An entry is a candidate, not a promise:
it gets a version pin, a `source.lua` and a `generic.lua` when it is picked
up, and it only becomes `- [x]` after that build succeeds on a system here.

Selection rules, applied to all three lists:

- C or C++ only, and developer-facing: build and packaging tools, test and
  analysis tools, and the compression, protocol, text, graphics, audio and
  numeric libraries that C/C++ programs are written against. No end-user
  applications, no language runtimes, and nothing already in `packages/`.
- Must build **serially** (`make -j1`, `cmake --build build --parallel 1`,
  `ninja -C build`), which is what retrolunar does everywhere, so peak memory
  stays under **2 GB**. Compiler runtimes, whole desktop stacks and anything
  that only builds in parallel are left out.
- Recipes must take their flags from the system (`$AUTOCONF_CONFIGURE_FLAGS`,
  `$CMAKE_FLAGS`, `$MESON_FLAGS`, `$CC`, `$CFLAGS`, `$PKG_CONFIG_LIBDIR`, ...)
  and may not hardcode target facts: those come from `$HOST_TRIPLET`,
  `$HOST_ARCH` and `$HOST_OS`.
- No version here on purpose: the pin is checked against upstream at fetch
  time, so a guess in this file would only be stale text.

Popularity ordering is from knowledge of the C/C++ ecosystem, not a fresh
crawl: web search was unavailable while these were written. Treat the order
as "roughly how often a developer reaches for it".

## Android candidates (100)

- [x] Brotli 1.1.0 (static libbrotlienc/libbrotlidec/libbrotlicommon plus the brotli/brotlicli tools; archive members are elf64-littleaarch64; pkg-config --modversion libbrotlienc reports 1.1.0. Needed -lm: the zopfli encoder path calls log2(), which Bionic keeps out of libc, so the Android systems now carry it in LDFLAGS)
- [x] Snappy 1.2.2 (static libsnappy.a, archive members are elf64-littleaarch64. Note: 1.2.2 installs a CMake package config, not snappy.pc, so consumers link -lsnappy or use find_package)
- [ ] Zopfli
- [ ] ISA-L (blocked: Makefile.unx is a native-build makefile. Its arch and
  host_cpu come from uname, so on an x86-64 build machine it selects x86 SIMD
  sources and adds -fcf-protection, which aarch64 rejects; forcing them to the
  target switches it to AS=$(CC) -D__ASSEMBLY__, and then its crc/igzip aarch64
  assembly fails to assemble under the NDK clang integrated assembler.
  Separately make.inc probes for -lpthread and, when the probe fails, still
  leaves -lpthread on the link line, which no Android sysroot can satisfy.
  All three need upstream changes, and no-patch is the rule)
- [x] xxHash 0.8.2 (static libxxhash.a, xxhsum tool, libxxhash.pc reporting 0.8.2; archive members are elf64-littleaarch64. Note: the CMake build lives in cmake_unofficial/, and it needs -DCMAKE_POLICY_VERSION_MINIMUM=3.5 under cmake 4.x)
- [x] Zlib-ng 2.2.4 (static libz-ng.a with the plain zlib API, ZLIB_COMPAT=OFF; pkg-config --modversion zlib-ng reports 2.2.4; archive members are elf64-littleaarch64)
- [ ] Minizip
- [x] minizip-ng 4.0.10 (static libminizip-ng.a; pkg-config --modversion minizip-ng reports 4.0.10; archive members are elf64-littleaarch64. Linked against the zlib-ng, bzip2, xz, zstd and OpenSSL in this prefix - MZ_FETCH_LIBS is off, which is the switch that stops it downloading and installing its own copies; ZipCrypto, PKWARE and AES encryption on; tools and tests off)
- [ ] zziplib
- [x] libarchive 3.8.1 (static libarchive.a with the zlib, bzip2, xz, lz4 and zstd backends from this prefix; pkg-config --modversion libarchive reports 3.8.1; archive members are elf64-littleaarch64. Note: archive.h includes private Android syscall wrappers from contrib/android/include, so the recipe appends that to CPPFLAGS)
- [ ] lzop
- [ ] lrzip
- [ ] p7zip
- [x] giflib 5.2.2 (static libgif.a and gif_lib.h; archive members are elf64-littleaarch64. Upstream ships a plain makefile, not configure, and no pkg-config file, so the recipe hands make the system's CC/CFLAGS/LDFLAGS/PREFIX and consumers link -lgif)
- [ ] jasper
- [x] lcms2 2.17 (static liblcms2.a with the JPEG and TIFF plug-ins from this prefix; pkg-config --modversion lcms2 reports 2.17. Utilities and Python bindings off)
- [x] draco 1.5.7 (static libdraco.a with encoder and decoder, draco/ headers; archive members are elf64-littleaarch64. gtest suite off. No pkg-config file upstream, so link -ldraco)
- [ ] meshoptimizer
- [x] cJSON 1.7.19 (static libcjson.a; archive members are elf64-littleaarch64; cJSON_add and cJSON_pretty installed. Upstream ships no pkg-config file, so consumers link -lcjson and use find_package(cJSON) instead. Note: the installed CMake config needed the loader's staging-path rewrite - it originally pointed at the build's staging dir, which broke the first consumer, msgpack-c)
- [x] Jansson 2.14 (static libjansson.a; pkg-config --modversion jansson reports 2.14; archive members are elf64-littleaarch64)
- [ ] json-c
- [x] nlohmann-json 3.11.3 (header-only: include/nlohmann/json.hpp plus a CMake package config and nlohmann_json.pc. Nothing is compiled, so it is identical on every system)
- [ ] RapidJSON
- [x] SimdJSON 3.12.3 (static libsimdjson.a, normal headers plus the generated single simdjson.h; pkg-config --modversion simdjson reports 3.12.3; archive members are elf64-littleaarch64. Note: only the library target is built: upstream adds tests/benchmarks/fuzzers on 64-bit with no option to disable, and those host programs link -lrt, absent in Bionic)
- [x] YAML-CPP 0.8.0 (static libyaml-cpp.a; pkg-config --modversion yaml-cpp reports 0.8.0; archive members are elf64-littleaarch64)
- [x] libyaml 0.2.5 (static libyaml.a; pkg-config --modversion yaml-0.1 reports 0.2.5; archive members are elf64-littleaarch64. Note: fetched from pyyaml.org, since the GitHub tag archive ships no generated configure; the recipe falls back to the GitHub release asset)
- [x] TinyXML-2 10.0.0 (static libtinyxml2.a; pkg-config --modversion tinyxml2 reports 10.0.0; archive members are elf64-littleaarch64)
- [x] Pugixml 1.15 (static libpugixml.a; pkg-config --modversion pugixml reports 1.15; archive members are elf64-littleaarch64)
- [x] tomlplusplus 3.4.0 (header-only: include/toml++/toml.hpp plus a CMake package config. Nothing compiled, so it is identical on every system)
- [x] toml11 4.4.0 (header-only: include/toml11/ headers, include/toml.hpp and a CMake package config. Nothing compiled, so it is identical on every system)
- [ ] libconfig
- [ ] libcbor
- [x] msgpack-c 7.0.2 (static libmsgpack-c.a, msgpack.h and msgpack/ headers; pkg-config --modversion msgpack-c reports 7.0.2; archive members are elf64-littleaarch64. Consumed by msgpack 5.x, which builds against it)
- [x] abseil-cpp 20260817.0 (94 static libabsl_*.a archives, absl/ headers, one absl_<name>.pc per module and a lib/cmake/absl package config; archive members are elf64-littleaarch64. ABSL_BUILD_TESTING=OFF so the GoogleTest fetch and the test binaries stay out. Required by protobuf 22+, so it is the first link of that chain. Note upstream ships no aggregate absl.pc, so use find_package(absl) or link the per-module .pc files)
- [ ] Cap'n
- [ ] Proto
- [x] FlatBuffers 25.2.10 (static libflatbuffers.a plus the flatc schema compiler and its code generators; pkg-config --modversion flatbuffers reports 25.2.10; archive members are elf64-littleaarch64. Note: flatc is built for the target and never run here; generate code with a host flatc)
- [ ] protobuf
- [ ] protobuf-c (blocked on its dependency: 1.5.1's configure requires Google protobuf >= 3.0.0, i.e. the libprotobuf C++ runtime. Google protobuf itself needs abseil, so this is a chain: abseil-cpp, then protobuf, then protobuf-c)
- [ ] nanopb
- [x] c-ares 1.34.8 (static libcares.a; pkg-config --modversion libcares reports 1.34.8; archive members are elf64-littleaarch64. Tools and tests off)
- [x] libevent 2.1.12-stable (static libevent, libevent_core, libevent_extra and libevent_openssl against the OpenSSL in this prefix; pkg-config --modversion libevent reports 2.1.12-stable; archive members are elf64-littleaarch64)
- [x] libuv 1.51.0 (static libuv.a, uv.h and uv/, CMake package config; archive members are elf64-littleaarch64. Note: 1.51.0 installs no pkg-config file, so link -luv or use find_package(libuv))
- [x] nghttp2 1.68.0 (static libnghttp2.a; pkg-config --modversion libnghttp2 reports 1.68.0; archive members are elf64-littleaarch64. Applications, tests, bindings and every optional dependency off, so the library needs only libc)
- [ ] libssh2
- [ ] libgit2
- [x] mbedTLS 3.6.3 (static libmbedtls, libmbedx509 and libmbedcrypto; pkg-config --modversion mbedtls reports 3.6.3; archive members are elf64-littleaarch64. Programs and tests off)
- [x] wolfSSL 5.8.2 (static libwolfssl.a with WOLFSSL_OPENSSLEXTRA; pkg-config --modversion wolfssl reports 5.8.2; archive members are elf64-littleaarch64. Examples and the crypt test program off - the latter needs the platform liblog through WOLFSSL_ANDROID_DEBUG)
- [ ] libsodium (blocked: upstream no longer serves the Unix release tarball — https://www.libsodium.org/releases/libsodium-1.0.20.tar.gz now 307-redirects to the documentation site — and the GitHub release 1.0.20-RELEASE ships only mingw and msvc assets. The GitHub tag archive has no generated configure, so it would need autoreconf with the native autotools)
- [ ] Botan
- [ ] nettle
- [ ] libgcrypt
- [x] pcre2 10.45 (static libpcre2-8/16/32 plus libpcre2-posix, JIT on; pkg-config --modversion libpcre2-8 reports 10.45; archive members are elf64-littleaarch64; pcre2grep, pcre2test and pcre2-config installed. C++ disabled, so pcre2grep is a C program)
- [ ] Oniguruma
- [ ] libcap
- [ ] libseccomp
- [ ] libnl-3
- [ ] hwloc
- [ ] libnuma
- [ ] libunwind
- [x] utf8proc 2.9.0 (static libutf8proc.a, Unicode tables compiled in; pkg-config --modversion libutf8proc reports 2.9.0; archive members are elf64-littleaarch64)
- [ ] ICU4C
- [ ] libxml2
- [ ] libxslt
- [ ] graphite2
- [x] FriBidi 1.0.16 (static libfribidi.a; pkg-config --modversion fribidi reports 1.0.16; archive members are elf64-littleaarch64. Note: the recipe adds -Ddefault_library=static, since meson builds shared by default and omits DESTDIR, since --prefix is already $OUT)
- [x] harfbuzz 14.5.0 (static libharfbuzz.a with the FreeType and FriBidi integrations from this prefix; pkg-config --modversion harfbuzz reports 14.5.0; archive members are elf64-littleaarch64. Tests, utilities and glib/cairo/ICU integrations off)
- [ ] fontconfig
- [ ] cairo
- [ ] pixman
- [ ] pango
- [ ] GLFW
- [ ] GLEW
- [ ] GLAD
- [ ] GLM
- [ ] ImGui
- [ ] stb
- [ ] tinyexr
- [ ] OpenAL-Soft
- [ ] miniaudio
- [ ] PortAudio
- [ ] libsndfile
- [x] libvorbis 1.3.7 (static libvorbis, libvorbisenc and libvorbisfile; pkg-config --modversion vorbis reports 1.3.7; archive members are elf64-littleaarch64. Needs libogg, which is now in the prefix)
- [x] libogg 1.3.5 (static libogg.a; pkg-config --modversion ogg reports 1.3.5; archive members are elf64-littleaarch64)
- [x] FLAC 1.5.0 (static libFLAC and libFLAC++ against the libogg in this prefix; pkg-config --modversion flac reports 1.5.0; archive members are elf64-littleaarch64)
- [ ] opusfile
- [ ] mpg123
- [ ] soxr
- [ ] SpeexDSP
- [ ] libmysofa
- [ ] soundtouch
- [x] fmt 11.1.4 (static libfmt.a, fmt/ headers and fmt.pc reporting 11.1.4; archive members are elf64-littleaarch64)
- [x] spdlog 1.15.3 (static libspdlog.a; pkg-config --modversion spdlog reports 1.15.3; archive members are elf64-littleaarch64. Needs fmt, which is now in the prefix; built with SPDLOG_FMT_EXTERNAL so the tree has one formatting engine)
- [ ] plog
- [ ] glog
- [ ] Log4cxx
- [x] Catch2 3.8.1 (static libCatch2.a and libCatch2Main.a, catch2/ headers and a CMake package config; archive members are elf64-littleaarch64. No pkg-config file upstream, so use find_package(Catch2))
- [x] doctest 2.4.11 (header-only: include/doctest/doctest.h plus a CMake package config. Nothing compiled, so it is identical on every system)
- [x] GoogleTest 1.17.0 (static libgtest.a, libgtest_main.a, libgmock.a and libgmock_main.a; pkg-config --modversion gtest and gmock both report 1.17.0; archive members are elf64-littleaarch64. Its own test suites off. Note: do not pass -DINSTALL_GTEST=OFF - googletest's install rules live inside that option's guard, so it installs nothing)
- [ ] Google-Benchmark
- [ ] Criterion3

## Windows (mingw-w64) candidates (100)

- [ ] Brotli
- [ ] Zopfli
- [ ] Snappy
- [ ] ISA-L
- [ ] xxHash
- [ ] Zlib-ng
- [ ] zziplib
- [ ] 7-Zip
- [ ] Minizip
- [ ] minizip-ng
- [ ] libarchive
- [ ] lzop
- [ ] lrzip
- [ ] giflib
- [ ] jasper
- [ ] openjpeg
- [ ] lcms2
- [ ] draco
- [ ] meshoptimizer
- [ ] PhysFS
- [ ] utf8proc
- [ ] ICU4C
- [ ] libxml2
- [ ] libxslt
- [ ] libyaml
- [ ] cmark
- [ ] Gumbo
- [ ] Lexbor
- [ ] graphite2
- [ ] FriBidi
- [ ] harfbuzz
- [ ] fontconfig
- [ ] cJSON
- [ ] Jansson
- [ ] json-c
- [ ] nlohmann-json
- [ ] RapidJSON
- [ ] SimdJSON
- [ ] YAML-CPP
- [ ] TinyXML2
- [ ] Pugixml
- [ ] tomlplusplus
- [ ] toml11
- [ ] libconfig
- [ ] fmt
- [ ] spdlog
- [ ] plog
- [ ] easylogging-plusplus
- [ ] glog
- [ ] Log4cxx
- [ ] range-v3
- [ ] tl-expected
- [ ] oneTBB
- [ ] oneDPL
- [ ] Eigen
- [ ] xtensor
- [ ] Highway
- [ ] Boost
- [ ] CGAL
- [ ] SuiteSparse
- [ ] FFTW
- [ ] OpenBLAS
- [ ] LAPACK
- [ ] KissFFT
- [ ] pcre2
- [ ] Oniguruma
- [ ] c-ares
- [ ] libevent
- [ ] libuv
- [ ] nghttp2
- [ ] libssh2
- [ ] libgit2
- [ ] mbedTLS
- [ ] wolfSSL
- [ ] libsodium
- [ ] Botan
- [ ] nettle
- [ ] libgcrypt
- [ ] cjose
- [ ] asn1c
- [ ] git
- [ ] GLFW
- [ ] GLEW
- [ ] GLAD
- [ ] GLM
- [ ] ImGui
- [ ] Vulkan-Headers
- [ ] tinyexr
- [ ] OpenAL-Soft
- [ ] miniaudio
- [ ] PortAudio
- [ ] libsndfile
- [ ] libvorbis
- [ ] libogg
- [ ] FLAC
- [ ] opusfile
- [ ] mpg123
- [ ] soxr
- [ ] SpeexDSP
- [ ] libmysofa

## Linux candidates (100)

- [ ] ccache
- [ ] distcc
- [ ] samu
- [ ] samurai
- [ ] re2c
- [ ] ragel
- [ ] cmph
- [ ] bear
- [ ] mold
- [ ] Universal-Ctags
- [ ] exuberant-ctags
- [ ] cscope
- [ ] astyle
- [ ] uncrustify
- [ ] cppcheck
- [ ] SWIG
- [ ] doxygen
- [ ] brotli
- [ ] Zopfli
- [ ] Snappy
- [ ] ISA-L
- [ ] xxHash
- [ ] Zlib-ng
- [ ] libarchive
- [ ] p7zip
- [ ] lzop
- [ ] lrzip
- [ ] minizip-ng
- [ ] zziplib
- [ ] squashfs-tools
- [ ] cpio
- [ ] pax
- [ ] dosfstools
- [ ] mtools
- [ ] lldb
- [ ] gdb
- [ ] valgrind
- [ ] strace
- [ ] ltrace
- [ ] heaptrack
- [ ] fmt
- [ ] spdlog
- [ ] plog
- [ ] easylogging-plusplus
- [ ] glog
- [ ] Log4cxx
- [ ] range-v3
- [ ] tl-expected
- [ ] oneTBB
- [ ] oneDPL
- [ ] Eigen
- [ ] xtensor
- [ ] Highway
- [ ] Boost
- [ ] CGAL
- [ ] SuiteSparse
- [ ] FFTW
- [ ] OpenBLAS
- [ ] LAPACK
- [ ] Armadillo
- [ ] nlohmann-json
- [ ] RapidJSON
- [ ] SimdJSON
- [ ] cJSON
- [ ] Jansson
- [ ] json-c
- [ ] yajl
- [ ] YAML-CPP
- [ ] libyaml
- [ ] TinyXML2
- [ ] Pugixml
- [ ] tomlplusplus
- [ ] toml11
- [ ] libconfig
- [ ] libcbor
- [ ] msgpack-c
- [ ] Cap'n-Proto
- [ ] FlatBuffers
- [ ] protobuf
- [ ] protobuf-c
- [ ] nanopb
- [ ] c-ares
- [ ] libevent
- [ ] libuv
- [ ] nghttp2
- [ ] libssh2
- [ ] libgit2
- [ ] mbedTLS
- [ ] wolfSSL
- [ ] libsodium
- [ ] Botan
- [ ] nettle
- [ ] libgcrypt
- [ ] pcre2
- [ ] Oniguruma
- [ ] libcap
- [ ] libseccomp
- [ ] libnl-3
- [ ] hwloc
- [ ] libnuma

