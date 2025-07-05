#!/bin/bash
set -e

# Toolchain helper script for OpenWrt builds
# Usage: ./toolchain-helper.sh <action> <repo_url> <repo_branch> <arch>
# Actions: check, download, compile

ACTION="$1"
REPO_URL="$2"
REPO_BRANCH="$3"
ARCH="$4"

if [ $# -lt 4 ]; then
    echo "Usage: $0 <action> <repo_url> <repo_branch> <arch>"
    echo "Actions: check, download, compile"
    echo "Arch: rockchip, armv8"
    exit 1
fi

# Generate toolchain filename
generate_toolchain_filename() {
    local repo_name=$(echo "$REPO_URL" | sed 's|.*/||' | sed 's|\.git||')
    local branch_safe=$(echo "$REPO_BRANCH" | sed 's|/|-|g')
    echo "${repo_name}-${branch_safe}-${ARCH}-toolchain.tar.gz"
}

# Check if toolchain exists
check_toolchain() {
    local toolchain_file=$(generate_toolchain_filename)
    echo "TOOLCHAIN_FILE=$toolchain_file" >> $GITHUB_ENV
    
    if curl -s -f -I "https://github.com/${GITHUB_REPOSITORY}/releases/download/toolchain/$toolchain_file" > /dev/null; then
        echo "exists=true" >> $GITHUB_OUTPUT
        echo "Toolchain cache found: $toolchain_file"
    else
        echo "exists=false" >> $GITHUB_OUTPUT
        echo "Toolchain cache not found: $toolchain_file"
    fi
}

# Download toolchain
download_toolchain() {
    local toolchain_file=$(generate_toolchain_filename)
    echo "Downloading toolchain: $toolchain_file"
    
    cd openwrt
    wget -q "https://github.com/${GITHUB_REPOSITORY}/releases/download/toolchain/$toolchain_file"
    tar -xf "$toolchain_file" --strip-components=1
    rm -f "$toolchain_file"
    echo "Toolchain downloaded and extracted successfully"
}

# Compile toolchain
compile_toolchain() {
    local toolchain_file=$(generate_toolchain_filename)
    echo "Compiling toolchain: $toolchain_file"

    cd openwrt
    make defconfig
    make toolchain/compile -j$(nproc) || make toolchain/compile -j1 V=s

    # Package toolchain with size optimization
    echo "Packaging toolchain (optimized for size)..."

    # Clean up unnecessary files to reduce size
    find staging_dir -name "*.a" -size +10M -delete 2>/dev/null || true
    find build_dir -name "*.o" -delete 2>/dev/null || true
    find build_dir -name "*.la" -delete 2>/dev/null || true
    find staging_dir -name "*.la" -delete 2>/dev/null || true

    # Remove documentation and man pages
    rm -rf staging_dir/*/share/man 2>/dev/null || true
    rm -rf staging_dir/*/share/doc 2>/dev/null || true
    rm -rf staging_dir/*/share/info 2>/dev/null || true

    # Package only essential directories
    local toolchain_dirs=""
    [ -d staging_dir ] && toolchain_dirs="$toolchain_dirs staging_dir"
    [ -d build_dir/host ] && toolchain_dirs="$toolchain_dirs build_dir/host"
    [ -d build_dir/toolchain-* ] && toolchain_dirs="$toolchain_dirs build_dir/toolchain-*"

    if [ -n "$toolchain_dirs" ]; then
        # Use higher compression to reduce file size
        tar --exclude='*.tmp' --exclude='*.log' --exclude='build_dir/*/tmp' \
            -I 'gzip -9' -cf "../$toolchain_file" $toolchain_dirs

        # Check file size
        local file_size=$(stat -c%s "../$toolchain_file" 2>/dev/null || stat -f%z "../$toolchain_file" 2>/dev/null || echo "0")
        local size_mb=$((file_size / 1024 / 1024))
        echo "Toolchain package size: ${size_mb}MB"

        if [ $file_size -gt 2000000000 ]; then
            echo "Warning: Toolchain package is larger than 2GB (${size_mb}MB)"
            echo "Attempting further optimization..."

            # More aggressive cleanup for oversized packages
            rm -rf staging_dir/*/include/c++/*/tr1 2>/dev/null || true
            rm -rf staging_dir/*/lib/gcc/*/include-fixed 2>/dev/null || true
            find staging_dir -name "*.a" -size +5M -delete 2>/dev/null || true

            # Repackage with maximum compression
            tar --exclude='*.tmp' --exclude='*.log' --exclude='build_dir/*/tmp' \
                --exclude='staging_dir/*/share' \
                -I 'gzip -9' -cf "../$toolchain_file" $toolchain_dirs

            file_size=$(stat -c%s "../$toolchain_file" 2>/dev/null || stat -f%z "../$toolchain_file" 2>/dev/null || echo "0")
            size_mb=$((file_size / 1024 / 1024))
            echo "Optimized toolchain package size: ${size_mb}MB"

            # If still too large, skip caching
            if [ $file_size -gt 2000000000 ]; then
                echo "Toolchain is still too large (${size_mb}MB), skipping cache upload"
                rm -f "../$toolchain_file"
                mkdir -p "$GITHUB_WORKSPACE/output"
                touch "$GITHUB_WORKSPACE/output/.skip_toolchain_cache"
                echo "Toolchain compiled successfully but cache skipped due to size"
                return 0
            fi
        fi

        mkdir -p "$GITHUB_WORKSPACE/output"
        mv "../$toolchain_file" "$GITHUB_WORKSPACE/output/"
        echo "Toolchain compiled and packaged successfully"
    else
        echo "Warning: No toolchain directories found to package"
        exit 1
    fi
}

case "$ACTION" in
    check)
        check_toolchain
        ;;
    download)
        download_toolchain
        ;;
    compile)
        compile_toolchain
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Available actions: check, download, compile"
        exit 1
        ;;
esac
