return recipe({
    version = "84.0.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/setuptools.whl ]; then
          curl -fSL -C - -o dl/setuptools.whl "https://files.pythonhosted.org/packages/95/9c/c510029fc6ef33a6275cd2c5d3cecd6613dfd6aa401d57c54f1c18852ccf/setuptools-84.0.0-py3-none-any.whl"
        fi
        rm -rf src
        mkdir -p src
        python3 -m zipfile -e dl/setuptools.whl src
        mkdir -p $OUT/setuptools
        cp -r src/* $OUT/setuptools/
    ]]
})
