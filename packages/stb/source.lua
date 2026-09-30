-- stb publishes no tags and no release assets: it is a rolling trunk that
-- upstream bumps by hand. Pin the exact commit instead, and use its date as
-- the version so the tree records which snapshot this is.
return recipe({
    version = "20260802",
    build = [[
        mkdir -p dl
        if [ ! -f dl/stb.tar.gz ]; then
          curl -fSL -C - -o dl/stb.tar.gz "https://github.com/nothings/stb/archive/2c980bb59875b0d32144a71867fbdebb2f77cd20.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/stb.tar.gz -C src --strip-components=1
        mkdir -p $OUT/stb
        cp -r src/* $OUT/stb/
    ]]
})
