-- oneDPL now lives at github.com/uxlfoundation/oneDPL (it moved out of
-- oneapi-src after the UXL Foundation took over the project; the README
-- in the tree links there). Release tags are oneDPL-release-YYYY.N.0, and
-- 2022.14.0 is the newest release tag on either repository.
return recipe({
    version = "2022.14.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/oneDPL.tar.gz ]; then
          curl -fSL -C - -o dl/oneDPL.tar.gz "https://github.com/oneapi-src/oneDPL/archive/refs/tags/oneDPL-release-2022.14.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/oneDPL.tar.gz -C src --strip-components=1
        mkdir -p $OUT/dpl
        cp -r src/* $OUT/dpl/
    ]]
})
