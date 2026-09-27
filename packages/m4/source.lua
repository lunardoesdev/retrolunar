return recipe({
    version = "1.4.20",
    build = [[
        mkdir -p dl
        if [ ! -f dl/m4.tar.gz ]; then
          curl -fSL -C - -o dl/m4.tar.gz "https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/m4.tar.gz -C src --strip-components=1
        mkdir -p $OUT/m4
        cp -r src/* $OUT/m4/
    ]]
})
