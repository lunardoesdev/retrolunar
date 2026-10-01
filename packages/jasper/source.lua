return recipe({
    version = "4.2.9",
    build = [[
        mkdir -p dl
        if [ ! -f dl/jasper.tar.gz ]; then
          curl -fSL -C - -o dl/jasper.tar.gz "https://github.com/jasper-software/jasper/archive/refs/tags/version-4.2.9.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/jasper.tar.gz -C src --strip-components=1
        mkdir -p $OUT/jasper
        cp -r src/* $OUT/jasper/
    ]]
})
