return recipe({
    version = "131.2.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/kissfft.tar.gz ]; then
          curl -fSL -C - -o dl/kissfft.tar.gz "https://github.com/mborgerding/kissfft/archive/refs/tags/131.2.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/kissfft.tar.gz -C src --strip-components=1
        mkdir -p $OUT/kissfft
        cp -r src/* $OUT/kissfft/
    ]]
})