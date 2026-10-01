return recipe({
    version = "1.1.45",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libxslt.tar.gz ]; then
          curl -fSL -C - -o dl/libxslt.tar.gz "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.45.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/libxslt.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libxslt
        cp -r src/* $OUT/libxslt/
    ]]
})