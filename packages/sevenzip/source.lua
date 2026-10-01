-- 7-Zip, upstream project of Igor Pavlov (7-zip.org / github.com/ip7z/7zip).
--
-- Directory name: "sevenzip", not "7zip". A package name is a directory name
-- and a `require()` token; `7zip` would start with a digit and could not be
-- spelled as `require("7zip")` or `7zip@sys` without quoting, and `7z` collides
-- conceptually with the archive format rather than the program. "sevenzip" is
-- the plainest lowercase spelling that names the project unambiguously.
--
-- Layout: 7z2603-src.tar.xz has NO top-level wrapper directory. Its 1292 members
-- sit directly under four top-level names -- Asm/, C/, CPP/ and DOC/ (1092 of
-- them under CPP/). So --strip-components must NOT be used: stripping one
-- component would remove CPP/, C/, Asm/ and DOC/ themselves and flatten the
-- C++ sources up one level, which is exactly what the makefiles' `../../../..`
-- source references do not expect.
return recipe({
    version = "26.03",
    build = [[
        mkdir -p dl
        if [ ! -f dl/7z2603-src.tar.xz ]; then
          curl -fSL -C - -o dl/7z2603-src.tar.xz "https://github.com/ip7z/7zip/releases/download/26.03/7z2603-src.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        # No --strip-components: the tarball has no top-level wrapper dir, and
        # stripping one would delete CPP/ and C/ themselves.
        tar -xJf dl/7z2603-src.tar.xz -C src
        mkdir -p $OUT/sevenzip
        cp -r src/* $OUT/sevenzip/
    ]]
})