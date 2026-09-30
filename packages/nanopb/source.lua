return recipe({
    version = "0.4.9.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/nanopb.tar.gz ]; then
          curl -fSL -C - -o dl/nanopb.tar.gz "https://github.com/nanopb/nanopb/releases/download/nanopb-0.4.9.2/nanopb-0.4.9.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/nanopb.tar.gz -C src --strip-components=1
        mkdir -p $OUT/nanopb
        cp -r src/* $OUT/nanopb/
    ]]
})