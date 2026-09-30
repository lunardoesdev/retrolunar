return recipe({
    version = "2.17",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lcms2.tar.gz ]; then
          curl -fSL -C - -o dl/lcms2.tar.gz "https://github.com/mm2/Little-CMS/releases/download/lcms2.17/lcms2-2.17.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lcms2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lcms2
        cp -r src/* $OUT/lcms2/
    ]]
})
