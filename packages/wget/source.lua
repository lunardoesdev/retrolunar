return recipe({
    version = "1.25.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/wget.tar.gz ]; then
          curl -fSL -C - -o dl/wget.tar.gz "https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/wget.tar.gz -C src --strip-components=1
        mkdir -p $OUT/wget
        cp -r src/* $OUT/wget/
    ]]
})
