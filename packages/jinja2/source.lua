return recipe({
    version = "3.1.6",
    build = [[
        mkdir -p dl
        if [ ! -f dl/jinja2.tar.gz ]; then
          curl -fSL -C - -o dl/jinja2.tar.gz "https://pypi.org/packages/source/j/jinja2/jinja2-3.1.6.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/jinja2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/jinja2
        cp -r src/* $OUT/jinja2/
    ]]
})
