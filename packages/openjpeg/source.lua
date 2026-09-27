return recipe({
    version = "2.5.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/openjpeg.tar.gz ]; then
          curl -fSL -C - -o dl/openjpeg.tar.gz "https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/openjpeg.tar.gz -C src --strip-components=1
        mkdir -p $OUT/openjpeg
        cp -r src/* $OUT/openjpeg/
    ]]
})
