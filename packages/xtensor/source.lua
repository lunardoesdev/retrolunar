-- xtensor is at github.com/xtensor-stack/xtensor, part of the xtensor-stack
-- organisation it shares with xtl, xsimd and friends.
return recipe({
    version = "0.27.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/xtensor.tar.gz ]; then
          curl -fSL -C - -o dl/xtensor.tar.gz "https://github.com/xtensor-stack/xtensor/archive/refs/tags/0.27.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/xtensor.tar.gz -C src --strip-components=1
        mkdir -p $OUT/xtensor
        cp -r src/* $OUT/xtensor/
    ]]
})
