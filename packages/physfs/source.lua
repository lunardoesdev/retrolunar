return recipe({
    version = "3.2.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/physfs.tar.gz ]; then
          curl -fSL -C - -o dl/physfs.tar.gz "https://github.com/icculus/physfs/archive/refs/tags/release-3.2.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/physfs.tar.gz -C src --strip-components=1
        mkdir -p $OUT/physfs
        cp -r src/* $OUT/physfs/
    ]]
})
