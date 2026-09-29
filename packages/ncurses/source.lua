-- LFS pins ncurses-6.5-20250809, a dated patch release that GNU no longer
-- publishes. Use the current stable release instead.
return recipe({
    version = "6.6",
    build = [[
        mkdir -p dl
        if [ ! -f dl/ncurses.tar.gz ]; then
          curl -fSL -C - -o dl/ncurses.tar.gz "https://ftp.gnu.org/gnu/ncurses/ncurses-6.6.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/ncurses.tar.gz -C src --strip-components=1
        mkdir -p $OUT/ncurses
        cp -r src/* $OUT/ncurses/
    ]]
})
