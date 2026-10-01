return recipe({
    version = "2.15.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libxml2.tar.xz ]; then
          curl -fSL -C - -o dl/libxml2.tar.xz "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.4.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/libxml2.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libxml2
        cp -r src/* $OUT/libxml2/
    ]]
})