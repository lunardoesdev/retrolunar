# lcms2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.17 (GitHub release asset `lcms2-2.17.tar.gz`)
- Build system: autotools
- Installs: static `liblcms2.a`, `lcms2.h`/`lcms2_plugin.h`, `lcms2.pc`. No
  tools: `--disable-utils` at `generic.lua:12`.
- Requires: `zlib` (exists), `libjpeg-turbo` (exists), `libtiff` (exists).
  All three are passed explicitly with `--with-jpeg="$PREFIX"` /
  `--with-tiff="$PREFIX"` rather than being left to autodetection.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Three switches do the work: `--disable-utils` removes `jpgicc`, `tificc`, `linkicc`, `transicc` and `tifficc` (host programs, and `tifficc`/`jpgicc` would need the very plug-ins being built); `--without-python` removes the bindings, which would need a target Python; and the two `--with-*` flags point at `$PREFIX` so the JPEG and TIFF plug-ins link against this tree's copies rather than anything in the sysroot. The timestamp guard at `:14-15` prevents the `aclocal-1.17` re-run. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `--with-jpeg`/`--with-tiff` point at `$PREFIX` regardless of host. |
| clang-native | WILL BUILD | As above. |

**API level notes.** lcms2's core is portable C; the plug-ins call into
libjpeg-turbo and libtiff, which are in the prefix and already build for every
system. No API-gated symbol is involved. `armv7a-android*` and `i686-android*`
match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **A static-library link-order subtlety is the real risk here.** A `.a` with
   JPEG and TIFF plug-ins records undefined references to `jpeg_*` and
   `TIFF*`. A consumer that links `liblcms2.a` must also link `libjpeg.a` and
   `libtiff.a`, and `lcms2.pc` has to say so. Verify `Libs.private` (or `Libs:`
   if upstream put them there) actually names both — if it does not, the
   package builds fine and every consumer fails at link time. This is the same
   class of latent problem as the `-llog` finding in abseil, and it is why the
   `pkg-config --libs` check below matters.
2. **`zlib` is required but only used by the utilities** (per the recipe's own
   comment at `generic.lua:9-10`), and `--disable-utils` turns those off. So
   `require("zlib")` at `generic.lua:1` is probably unnecessary now. Harmless,
   but it is a dependency edge with no consumer.
3. The recipe passes `--with-jpeg`/`--with-tiff` with an explicit prefix, which
   is the right thing to do — the alternative is lcms2 finding whatever
   `libjpeg` happens to be first on the search path, which on Android would be
   the NDK's own.
4. `topackage.md` records this as built: *"static liblcms2.a with the JPEG and
   TIFF plug-ins from this prefix; pkg-config --modversion lcms2 reports
   2.17."* Consistent with this forecast.

**How to verify once built.**

- `lib/liblcms2.a` exists.
- `include/lcms2.h` and `include/lcms2_plugin.h` exist.
- `pkg-config --modversion lcms2` reports 2.17.
- `$OBJDUMP -f lib/liblcms2.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm -u lib/liblcms2.a | grep -c 'jpeg_\|TIFF'` should be **non-zero**,
  proving the plug-ins really are in there; and
  `pkg-config --libs lcms2` must mention both `ljpeg`/`ljpeg-turbo` and
  `ltiff`, or consumers will fail.
- `ls $OUT/bin/` must be empty — a `tifficc` here means `--disable-utils`
  regressed.
