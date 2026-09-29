return recipe({
    version = "2.13.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/man-db.tar.xz ]; then
          # man-db is a nongnu package hosted on Savannah, not on ftp.gnu.org -
          # that is why the GNU path 404s. 2.13.1 is the newest in the release
          # directory.
          curl -fSL -C - -o dl/man-db.tar.xz "https://download.savannah.gnu.org/releases/man-db/man-db-2.13.1.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/man-db.tar.xz -C src --strip-components=1
        mkdir -p $OUT/man-db
        cp -r src/* $OUT/man-db/
    ]]
})
