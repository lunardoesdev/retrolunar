require("meson@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/meson/* .
        # Meson is pure Python with no C extension, so it installs as a module
        # plus its launcher script. LFS runs setup.py, which needs a target
        # Python interpreter to run; the module plus the bin/ launcher is what
        # build recipes actually use, so dist-info metadata is skipped here, as
        # with the other pure-Python entries in this backlog.
        mkdir -p $OUT/lib/python3.13/site-packages
        cp -r mesonbuild $OUT/lib/python3.13/site-packages/
        cp COPYING $OUT/lib/python3.13/site-packages/mesonbuild/COPYING
        mkdir -p $OUT/bin
        cp meson.py $OUT/bin/meson
        chmod +x $OUT/bin/meson
    ]]
})
