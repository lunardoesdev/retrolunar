return recipe({
    version = "5.2.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/giflib.tar.gz ]; then
          curl -fSL -C - -o dl/giflib.tar.gz "https://sourceforge.net/projects/giflib/files/giflib-5.2.2.tar.gz/download"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/giflib.tar.gz -C src --strip-components=1
        mkdir -p $OUT/giflib
        cp -r src/* $OUT/giflib/
    ]]
})
