require("freetype")
require("libpng")

return recipe({
    version = "0.1.0",
    libpng_sys = "1.1.11",
    build = [[
        rm -f "$PREFIX/lib/libxcadd.a" "$PREFIX/lib/pkgconfig/xcadd.pc"
        rm -rf "$PREFIX/include/xcadd"
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
        if ! "$READELF" -d "target/$CARGO_BUILD_TARGET/release/pngprobe" | grep -q "libpng16"; then
          echo "error: pngprobe did not link libpng16 from \$PREFIX" >&2
          echo "--- readelf dump: ---" >&2
          "$READELF" -d "target/$CARGO_BUILD_TARGET/release/pngprobe" >&2 || true
          exit 1
        fi
        mkdir -p "$OUT$PREFIX/bin"
        cp "target/$CARGO_BUILD_TARGET/release/pngprobe" "$OUT$PREFIX/bin/"
    ]]
})
