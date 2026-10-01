-- 7-Zip, upstream project of Igor Pavlov (7-zip.org / github.com/ip7z/7zip).
--
-- Directory name: "sevenzip", not "7zip". A package name is a directory name
-- and a `require()` token; `7zip` would start with a digit and could not be
-- spelled as `require("7zip")` or `7zip@sys` without quoting, and `7z` collides
-- conceptually with the archive format rather than the program. "sevenzip" is
-- the plainest lowercase spelling that names the project unambiguously.
--
-- The release asset `7z2603-src.tar.xz` unpacks with the tarball root being the
-- *contents* of upstream's `CPP/` directory (its 1092 `CPP/...` members are
-- flattened to the root). So --strip-components=1 is correct and lands C/,
-- CPP-subdirs such as 7zip/, Common/, Windows/ and the *.mak files side by side.
return recipe({
    version = "26.03",
    build = [[
        mkdir -p dl
        if [ ! -f dl/7z2603-src.tar.xz ]; then
          curl -fSL -C - -o dl/7z2603-src.tar.xz "https://github.com/ip7z/7zip/releases/download/26.03/7z2603-src.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/7z2603-src.tar.xz -C src --strip-components=1
        mkdir -p $OUT/sevenzip
        cp -r src/* $OUT/sevenzip/
    ]]
})