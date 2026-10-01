return recipe({
    version = "0.31.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/cmark.tar.gz ]; then
          curl -fSL -C - -o dl/cmark.tar.gz "https://github.com/commonmark/cmark/archive/refs/tags/0.31.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/cmark.tar.gz -C src --strip-components=1
        mkdir -p $OUT/cmark
        cp -r src/* $OUT/cmark/
    ]]
})