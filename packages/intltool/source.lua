return recipe({
    version = "0.51.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/intltool.tar.gz ]; then
          # Upstream's own download page (launchpad.net, the URL LFS cites) is
          # not serving the tarball any more, and download.gnome.org only
          # carries releases up to 0.40. Debian's pool mirror has the
          # unmodified upstream 0.51.0 release tarball.
          curl -fSL -C - -o dl/intltool.tar.gz "http://deb.debian.org/debian/pool/main/i/intltool/intltool_0.51.0.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/intltool.tar.gz -C src --strip-components=1
        mkdir -p $OUT/intltool
        cp -r src/* $OUT/intltool/
    ]]
})
