-- Minizip: NOT an upstream project of its own. It is the contrib/minizip/
-- directory inside the zlib release tarball, maintained by the zlib project and
-- versioned in lockstep with it (configure.ac:4 says AC_INIT([minizip],[1.3.1])).
-- There is no separate minizip release to fetch.
--
-- It is packaged here in its own right because the buildable artifact is a
-- different library from the one `packages/zlib/` produces. zlib's own
-- CMakeLists.txt builds only libz.a / libz.so from the top-level sources and
-- never descends into contrib/ -- `grep -n 'contrib' CMakeLists.txt` finds
-- nothing. So the contrib sources are genuinely additional, not duplicate, and
-- a separate package is warranted. See stage1.md for how the two relate and
-- what that costs.
--
-- Version tracks zlib's, because that is the release the sources come from.
-- URL and layout are therefore identical to packages/zlib/source.lua; this
-- package re-fetches the same tarball rather than reading the zlib source
-- tree, because the two recipes must stay independent and packages/zlib/ is
-- not this package's to depend on.
return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/zlib.tar.gz ]; then
          curl -fSL -C - -o dl/zlib.tar.gz "https://zlib.net/fossils/zlib-1.3.1.tar.gz" || curl -fSL -C - -o dl/zlib.tar.gz "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/zlib.tar.gz -C src --strip-components=1
        mkdir -p $OUT/minizip
        cp -r src/* $OUT/minizip/
    ]]
})