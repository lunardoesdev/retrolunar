return recipe({
    version = "10.45",
    build = [[
        mkdir -p dl
        if [ ! -f dl/pcre2.tar.gz ]; then
          curl -fSL -C - -o dl/pcre2.tar.gz "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/pcre2.tar.gz -C src --strip-components=1
        mkdir -p $OUT/pcre2
        cp -r src/* $OUT/pcre2/
    ]]
})
