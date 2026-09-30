return recipe({
    version = "2.9.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/utf8proc.tar.gz ]; then
          curl -fSL -C - -o dl/utf8proc.tar.gz "https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.9.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/utf8proc.tar.gz -C src --strip-components=1
        mkdir -p $OUT/utf8proc
        cp -r src/* $OUT/utf8proc/
    ]]
})
