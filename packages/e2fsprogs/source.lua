return recipe({
    version = "1.47.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/e2fsprogs.tar.gz ]; then
          curl -fSL -C - -o dl/e2fsprogs.tar.gz "https://downloads.sourceforge.net/project/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/e2fsprogs.tar.gz -C src --strip-components=1
        mkdir -p $OUT/e2fsprogs
        cp -r src/* $OUT/e2fsprogs/
    ]]
})
