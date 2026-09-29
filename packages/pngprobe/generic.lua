require("freetype")
require("libpng")

return recipe({
    version = "0.1.0",
    libpng_sys = "1.1.11",
    build = [[
        mkdir -p src
        cat > Cargo.toml <<EOF
        [package]
        name = "pngprobe"
        version = "0.1.0"
        edition = "2021"
        [dependencies]
        libpng-sys = "=1.1.11"
        EOF
        mkdir -p src
        cat > src/main.rs <<'EOF'
        fn main() {
            let ver = unsafe { libpng_sys::ffi::png_access_version_number() };
            println!("libpng version: {ver}");
            assert!(ver >= 10648, "unexpected libpng version: {ver}");
        }
        EOF
        PNG_CONFIG="false" cargo build --release --target "$CARGO_BUILD_TARGET"
        _bin="target/$CARGO_BUILD_TARGET/release/pngprobe"
        [ -f "$_bin" ] || _bin="$_bin.exe"
        if ! "$OBJDUMP" -p "$_bin" | grep -qi "libpng16"; then
          echo "error: pngprobe did not link libpng16 from \$PREFIX" >&2
          echo "--- objdump dump: ---" >&2
          "$OBJDUMP" -p "$_bin" >&2 || true
          exit 1
        fi
        mkdir -p "$OUT/bin"
        cp "$_bin" "$OUT/bin/"
    ]]
})
