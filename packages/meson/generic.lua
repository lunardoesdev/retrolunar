require("meson@source")

-- Pure-python build tool: no compilation. Install the tree + wrapper.
return recipe({
    build = [[
        cp -r $NESTDIR/source/meson/* .
        mkdir -p $OUT/bin $OUT/lib/meson
        cp -r mesonbuild $OUT/lib/meson/
        cp meson.py $OUT/lib/meson/
        cat > $OUT/bin/meson <<EOF
        #!/bin/sh
        exec python3 "\$0_HERE/../lib/meson/meson.py" "\$@"
        EOF
        # Fix the wrapper to resolve relative to itself (no $0_HERE magic).
        cat > $OUT/bin/meson <<EOF
        #!/bin/sh
        _here="\$(cd "\$(dirname "\$0")" && pwd)"
        exec python3 "\$_here/../lib/meson/meson.py" "\$@"
        EOF
        chmod +x $OUT/bin/meson
    ]]
})
