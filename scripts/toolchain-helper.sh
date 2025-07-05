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
    
    # Package toolchain
    local toolchain_dirs=""
    [ -d staging_dir ] && toolchain_dirs="$toolchain_dirs staging_dir"
    [ -d build_dir/host ] && toolchain_dirs="$toolchain_dirs build_dir/host"
    [ -d build_dir/toolchain-* ] && toolchain_dirs="$toolchain_dirs build_dir/toolchain-*"

    if [ -n "$toolchain_dirs" ]; then
        tar -czf "../$toolchain_file" $toolchain_dirs
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
