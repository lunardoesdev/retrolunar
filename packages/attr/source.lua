return recipe({
    version = "2.5.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/attr.tar.gz ]; then
          curl -fSL -C - -o dl/attr.tar.gz "https://download.savannah.gnu.org/releases/attr/attr-2.5.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/attr.tar.gz -C src --strip-components=1
        mkdir -p $OUT/attr
        cp -r src/* $OUT/attr/
    ]]
})
