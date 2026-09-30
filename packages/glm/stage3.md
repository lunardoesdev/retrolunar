# glm 1.0.3 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-glm
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'glm@aarch64-android24' > /tmp/build-glm.sh
sh -n /tmp/build-glm.sh          # exit 0 — syntax gate passed
sh /tmp/build-glm.sh
```

## Stale-artifact cleanup — this package HAD stale artifacts

glm was one of the seven with a stamp left by the discarded run. Pre-build
inspection:

```
$ ls -d nest/aarch64-android24/include/glm \
      nest/aarch64-android24/share/glm \
      nest/aarch64-android24/lib/cmake/glm \
      nest/aarch64-android24/lib/libglm.a \
      nest/aarch64-android24/lib/pkgconfig/glm.pc
nest/aarch64-android24/include/glm
nest/aarch64-android24/share/glm
$ ls -a nest/aarch64-android24/.retrolunar-glm
nest/aarch64-android24/.retrolunar-glm
```

So a stamp **and** two artifact trees existed from the discarded run.
Deleted: the stamp, `include/glm/` (whole tree), `share/glm/` (whole tree),
`lib/cmake/glm`, `lib/libglm.a`, `lib/pkgconfig/glm.pc`.

Honest note on what I did and did not capture: I listed the two directories
as existing but did not record their file counts before removing them, so
"they contained N headers from the discarded run" is not something I can
claim. What I *can* assert is that both paths existed beforehand, that they
were removed, and that every artifact below was re-created by this build at
`Oct 1 03:17` — which the mtimes prove.

## Outcome: **SUCCESS**

glm is header-only, so **there is no compile step by design** and
consequently **there is no architecture to check**. This is stated in the
recipe's own comment and confirmed by the log: not one `Building CXX object`
line appears. The build is configure + install, and the install copied the
header tree file by file (`-- Installing: .../include/glm/...` for 432 files).

`GLM_BUILD_LIBRARY=OFF` took, and the preflight's named hazard at
`CMakeLists.txt:271` — `install(TARGETS glm-header-only glm EXPORT glm)` with
both targets `INTERFACE` and no `ARCHIVE`/`LIBRARY` destination — did **not**
fire. The install step completed normally and wrote both config files. The
documented fallback (drop `GLM_BUILD_LIBRARY=OFF`, accept a one-file
`libglm.a`) was **not** needed.

Install tail:

```
-- Installing: .../out-PhvVCP/include/glm/vec2.hpp
-- Installing: .../out-PhvVCP/include/glm/vec3.hpp
-- Installing: .../out-PhvVCP/include/glm/vec4.hpp
-- Installing: .../out-PhvVCP/include/glm/vector_relational.hpp
-- Installing: .../out-PhvVCP/share/glm/glmConfig.cmake
-- Installing: .../out-PhvVCP/share/glm/glmConfigVersion.cmake
```

## Artifact verification (real output)

The one command that proves it — `[ -f include/glm/glm.hpp ]`:

```
$ test -f nest/aarch64-android24/include/glm/glm.hpp
$ echo $?
0
$ ls -la nest/aarch64-android24/include/glm/glm.hpp
-rw-r--r-- 1 si si 4503 Oct  1 03:17 nest/aarch64-android24/include/glm/glm.hpp
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| whole header tree, recursively copied | `find $PREFIX/include/glm -type f \| wc -l` | `432` |
| CMake package config in **`share/glm`** | `ls -la $PREFIX/share/glm/` | `glmConfig.cmake` (4254 bytes), `glmConfigVersion.cmake` (1861 bytes), both `Oct 1 03:17` |
| **no `lib/cmake/glm`** | `ls -d $PREFIX/lib/cmake/glm` | `absent (correct)` |
| **no library file** | `ls $PREFIX/lib/libglm.a` | `absent (correct)` |
| **no pkg-config file** | `ls $PREFIX/lib/pkgconfig/glm.pc` | `absent (correct)` |

Spot checks across subtrees, to prove `install(DIRECTORY glm ...)` was
recursive and not a flat copy:

```
  OK gtc/matrix_transform.hpp
  OK gtx/quaternion.hpp
  OK ext/matrix_clip_space.hpp
  OK simd/neon.h
  OK detail/type_vec3.hpp
```

### One correction to the forecast

`stage2.md`'s table offered `[ -f include/glm/glm/vec2.hpp ]` as the
subtree check. That path is wrong — it fails on a **correct** build:

```
$ test -f nest/aarch64-android24/include/glm/glm/vec2.hpp
MISSING glm/vec2.hpp
$ ls nest/aarch64-android24/include/glm/glm
no include/glm/glm — stage2.md's check path was a typo
$ ls -la nest/aarch64-android24/include/glm/vec2.hpp
-rw-r--r-- 1 si si  437 Oct  1 03:17 nest/aarch64-android24/include/glm/vec2.hpp
```

`vec2.hpp` sits at the top of the installed tree (`include/glm/vec2.hpp`),
not under a second `glm/`. Had the forecast's command been used verbatim it
would have reported a false failure. Recorded as a stage2 typo, not a recipe
or build defect.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-glm.sh
skip glm@source (fresh)
skip glm@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made; `packages/glm/generic.lua` and `source.lua`
are committed unmodified.
