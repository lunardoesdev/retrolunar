-- tl::expected lives at github.com/TartanLlama/expected; the project is
-- "expected" and there is no separate "tl-expected" repository. Directory
-- name here is tl-expected so the require() spelling matches topackage.md.
return recipe({
    version = "1.3.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/tl-expected.tar.gz ]; then
          curl -fSL -C - -o dl/tl-expected.tar.gz "https://github.com/TartanLlama/expected/archive/refs/tags/v1.3.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/tl-expected.tar.gz -C src --strip-components=1
        mkdir -p $OUT/tl-expected
        cp -r src/* $OUT/tl-expected/
    ]]
})
