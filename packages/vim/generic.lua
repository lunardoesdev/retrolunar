require("vim@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/vim/. .
        # vim's configure is a hand-written script, not autoconf, so
        # $AUTOCONF_CONFIGURE_FLAGS does not apply and every option is passed
        # explicitly. --with-tlibdir is required or modern vim refuses to
        # configure; the terminal library stays in the prefix so vim's runtime
        # terminfo lookup uses ours.
        #
        # --host is required: vim's configure runs a test program to decide
        # whether it is cross compiling, and reports "cannot run C compiled
        # programs" without it.
        #
        # LFS additionally appends a SYS_VIMRC_FILE define to src/feature.h to
        # move the vimrc to /etc. That edits an upstream source, which this
        # project does not do, so the default location under the prefix is
        # kept instead.
        cd src
        ./configure --prefix="$OUT" \
            --host=aarch64-linux-android \
            --with-features=normal \
            --enable-multibyte \
            --with-tlibdir="$PREFIX/lib"
        make
        make install
    ]]
})
