require("zlib")
require("zziplib@source")

-- zziplib 0.13.78 is pure C (CMakeLists.txt:2 declares `LANGUAGES C`, and the
-- tree contains no .cpp/.cc/.hpp at all), so there is no C++ standard problem
-- and no -std= override is needed. The premise that this is "old C++" does not
-- hold for this version.
--
-- cmake is the right build system here: the tree ships CMakeLists.txt at the top
-- level and GNUmakefile:12-13 drives cmake, while the autotools path is
-- deliberately retired (configure.ac is renamed old.configure.ac and no
-- generated `configure` ships, so it would need autoreconf -- not an allowed
-- build-body verb).
--
-- Options, all verified present in zzip/CMakeLists.txt:
--   BUILD_SHARED_LIBS  ON by default; a target prefix has no loader path for a
--                      versioned .so, so build static like every other package.
--   ZZIPMMAPPED        stays ON (default). It is upstream's headline feature and
--                      its "not fully portable" warning refers to mmap-based
--                      seeking, which zziplib only uses when the caller asks.
--   ZZIPFSEEKO         OFF -- the plain fseeko variant, redundant next to
--                      libzzipmmapped.
--   ZZIP_COMPAT        OFF -- it generates compat/zzip.h with a ${BASH} -c
--                      heredoc + sed custom command (zzip/CMakeLists.txt:190).
--   ZZIP_PKGCONFIG     left ON so zziplib.pc installs, but it too is generated
--                      by a ${BASH} -c + sed custom command (:233). That is
--                      fine: the sed runs over files cmake itself produced in
--                      this build, not over upstream sources.
--   ZZIPSDL / ZZIPWRAP / ZZIPBINS / ZZIPTEST / ZZIPDOCS  all OFF -- they are
--                      host-side tooling or a GUI/SDL wrapper. ZZIPDOCS in
--                      particular find_package(PythonInterp 3.5 REQUIRED)
--                      (docs/CMakeLists.txt:23).
return recipe({
    build = [[
        cp -r $NESTDIR/source/zziplib/* .
        # Everything outside the zzip/ library is host-side tooling or a
        # GUI/SDL wrapper. ZZIPDOCS find_package(PythonInterp 3.5 REQUIRED)
        # (docs/CMakeLists.txt:23), so it has to go regardless.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DZZIPFSEEKO=OFF -DZZIP_COMPAT=OFF -DZZIPSDL=OFF -DZZIPWRAP=OFF -DZZIPBINS=OFF -DZZIPTEST=OFF -DZZIPDOCS=OFF
        cmake --build build --parallel 1
        cmake --install build
    ]]
})