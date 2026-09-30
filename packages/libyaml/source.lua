return recipe({
    version = "0.2.5",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libyaml.tar.gz ]; then
          # pyyaml.org is the canonical release host; the GitHub tag archive
          # has no generated configure.
          curl -fSL -C - -o dl/libyaml.tar.gz "https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz" || curl -fSL -C - -o dl/libyaml.tar.gz "https://github.com/yaml/libyaml/releases/download/0.2.5/yaml-0.2.5.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libyaml.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libyaml
        cp -r src/* $OUT/libyaml/
    ]]
})
