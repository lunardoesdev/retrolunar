return recipe({
    version = "4.7.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libtiff.tar.gz ]; then
          curl -fSL -C - -o dl/libtiff.tar.gz "https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libtiff.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libtiff
        cp -r src/* $OUT/libtiff/
    ]]
})
