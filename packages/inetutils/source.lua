return recipe({
    version = "2.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/inetutils.tar.gz ]; then
          curl -fSL -C - -o dl/inetutils.tar.gz "https://ftp.gnu.org/gnu/inetutils/inetutils-2.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/inetutils.tar.gz -C src --strip-components=1
        mkdir -p $OUT/inetutils
        cp -r src/* $OUT/inetutils/
    ]]
})
