-- range-v3 is developed at github.com/ericniebler/range-v3, which is the
-- canonical repository for the library (the range-v3/range-v3 org path does
-- not exist). Its newest release tag is 0.12.0; the two tags above it,
-- fork_point and fork_base, are merge markers, not releases.
return recipe({
    version = "0.12.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/range-v3.tar.gz ]; then
          curl -fSL -C - -o dl/range-v3.tar.gz "https://github.com/ericniebler/range-v3/archive/refs/tags/0.12.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/range-v3.tar.gz -C src --strip-components=1
        mkdir -p $OUT/range-v3
        cp -r src/* $OUT/range-v3/
    ]]
})
