-- NOT google/gumbo-parser. That repository was archived read-only on
-- 2026-01-21 and has had no development since 2016; its newest tag is
-- v0.10.1 (2015), it ships no generated `configure` (only configure.ac +
-- autogen.sh, which runs libtoolize/aclocal/autoconf/automake), and it has
-- no CMakeLists.txt at all. The maintained successor is GerHobbelt's
-- fork, which upstream's own successor line credits and which carries
-- releases through 0.14.0. Its meson.build is the real, supported build.
return recipe({
    version = "0.14.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gumbo.tar.gz ]; then
          curl -fSL -C - -o dl/gumbo.tar.gz "https://github.com/GerHobbelt/gumbo-parser/archive/refs/tags/0.14.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/gumbo.tar.gz -C src --strip-components=1
        mkdir -p $OUT/gumbo
        cp -r src/* $OUT/gumbo/
    ]]
})
