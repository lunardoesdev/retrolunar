return recipe({
    version = "1.6.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/dejagnu.tar.gz ]; then
          curl -fSL -C - -o dl/dejagnu.tar.gz "https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/dejagnu.tar.gz -C src --strip-components=1
        mkdir -p $OUT/dejagnu
        cp -r src/* $OUT/dejagnu/
    ]]
})
