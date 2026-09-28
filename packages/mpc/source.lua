return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/mpc.tar.gz ]; then
          curl -fSL -C - -o dl/mpc.tar.gz "https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/mpc.tar.gz -C src --strip-components=1
        mkdir -p $OUT/mpc
        cp -r src/* $OUT/mpc/
    ]]
})
