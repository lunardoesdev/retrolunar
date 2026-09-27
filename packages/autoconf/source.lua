return recipe({
    version = "2.72",
    build = [[
        mkdir -p dl
        if [ ! -f dl/autoconf.tar.gz ]; then
          curl -fSL -C - -o dl/autoconf.tar.gz "https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/autoconf.tar.gz -C src --strip-components=1
        mkdir -p $OUT/autoconf
        cp -r src/* $OUT/autoconf/
    ]]
})
