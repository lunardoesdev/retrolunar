return recipe({
    version = "1.15",
    build = [[
        mkdir -p dl
        if [ ! -f dl/pugixml.tar.gz ]; then
          curl -fSL -C - -o dl/pugixml.tar.gz "https://github.com/zeux/pugixml/archive/refs/tags/v1.15.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/pugixml.tar.gz -C src --strip-components=1
        mkdir -p $OUT/pugixml
        cp -r src/* $OUT/pugixml/
    ]]
})
