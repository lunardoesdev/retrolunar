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
        # --host comes from the system's $HOST_TRIPLET, never a literal.
        # It used to be hardcoded aarch64-linux-android, which on
        # x86_64-android35 configured an aarch64 tree into an x86_64 prefix
        # and on x86_64-mingw handed an aarch64 triplet to
        # x86_64-w64-mingw32-gcc. $HOST_TRIPLET expands to exactly that same
        # literal on the aarch64-android systems, so the one family that
        # worked is unaffected.
        ./configure --prefix="$OUT" \
            --host="$HOST_TRIPLET" \
            --with-features=normal \
            --enable-multibyte \
            --with-tlibdir="$PREFIX/lib"
        make
        make install
    ]]
})
