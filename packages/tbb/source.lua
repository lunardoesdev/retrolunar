-- oneTBB is developed at github.com/oneapi-src/oneTBB, the canonical
-- repository. Tags are v-prefixed years (v2023.1.0); there is no tarball
-- asset on the releases, so the tag archive is the release tarball.
return recipe({
    version = "2023.1.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/oneTBB.tar.gz ]; then
          curl -fSL -C - -o dl/oneTBB.tar.gz "https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2023.1.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/oneTBB.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tbb
        cp -r src/* $OUT/tbb/
    ]]
})
