return recipe({
    version = "1.58.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/pango.tar.xz ]; then
          curl -fSL -C - -o dl/pango.tar.xz "https://download.gnome.org/sources/pango/1.58/pango-1.58.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/pango.tar.xz -C src --strip-components=1
        mkdir -p $OUT/pango
        cp -r src/* $OUT/pango/
    ]]
})