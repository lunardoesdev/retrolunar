return recipe({
    version = "2.18.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/fontconfig.tar.xz ]; then
          # freedesktop.org's release directory stops at 2.16.0; 2.17.x and
          # 2.18.x ship only as GitLab generic packages. This matters: pango
          # 1.58.2 requires fontconfig >= 2.17.0 (pango meson.build:219), so
          # 2.16.0 could not satisfy it. This is upstream's own dist tarball
          # (it carries the generated configure, Makefile.in and config.h.in),
          # not a git archive.
          curl -fSL -C - -o dl/fontconfig.tar.xz "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/fontconfig.tar.xz -C src --strip-components=1
        mkdir -p $OUT/fontconfig
        cp -r src/* $OUT/fontconfig/
    ]]
})