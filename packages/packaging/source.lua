return recipe({
    version = "26.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/packaging.tar.gz ]; then
          curl -fSL -C - -o dl/packaging.tar.gz "https://files.pythonhosted.org/packages/7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/packaging.tar.gz -C src --strip-components=1
        mkdir -p $OUT/packaging
        cp -r src/* $OUT/packaging/
    ]]
})
