return recipe({
    version = "0.26",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gettext.tar.gz ]; then
          curl -fSL -C - -o dl/gettext.tar.gz "https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/gettext.tar.gz -C src --strip-components=1
        mkdir -p $OUT/gettext
        cp -r src/* $OUT/gettext/
    ]]
})
