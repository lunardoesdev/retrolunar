require("man-pages@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/man-pages/* .
        # Pure data: the tarball ships pre-formatted roff manuals, so they are
        # staged straight into the man directories.
        mkdir -p $OUT/share/man
        cp -r man $OUT/share/man/
        # The tarball also ships top-level man1/man3/... entries, but they are
        # symlinks into man/ and copying them would collide with the real
        # directories. Recreate the standard section links by hand instead.
        for _s in 1 2 3 4 5 6 7 8 9 n; do
          if [ -d "$OUT/share/man/man/man$_s" ]; then
            ln -sfn "man/man$_s" "$OUT/share/man/man$_s"
          fi
        done
    ]]
})
