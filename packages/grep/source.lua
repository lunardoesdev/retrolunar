return recipe({
    version = "3.12",
    build = [[
        mkdir -p dl
        if [ ! -f dl/grep.tar.xz ]; then
          curl -fSL -C - -o dl/grep.tar.xz "https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/grep.tar.xz -C src --strip-components=1
        mkdir -p $OUT/grep
        cp -r src/* $OUT/grep/
    ]]
})
