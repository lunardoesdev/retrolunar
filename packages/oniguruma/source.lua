return recipe({
    version = "6.9.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/onig.tar.gz ]; then
          curl -fSL -C - -o dl/onig.tar.gz "https://github.com/kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/onig.tar.gz -C src --strip-components=1
        mkdir -p $OUT/oniguruma
        cp -r src/* $OUT/oniguruma/
    ]]
})
