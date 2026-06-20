#!/bin/bash
set -e

# Make sure we're not running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root/sudo directly. It will run pacman with sudo when needed."
    exit 1
fi

echo "=== Rebuilding Thunar with square selection highlight ==="
BUILD_DIR=$(mktemp -d /tmp/thunar-build-XXXXXX)
cd "$BUILD_DIR"

echo "Cloning packaging repository..."
git clone https://gitlab.archlinux.org/archlinux/packaging/packages/thunar.git .

echo "Downloading and preparing source code..."
makepkg -od

echo "Applying patch to thunar-util.c..."
sed -i 's/#define BORDER_RADIUS 8/#define BORDER_RADIUS 0/g' src/thunar/thunar/thunar-util.c

echo "Generating configure script..."
cd src/thunar && NOCONFIGURE=1 ./autogen.sh && cd ../..

echo "Compiling and installing package..."
makepkg -esi --noconfirm

echo "Cleaning up..."
cd /
rm -rf "$BUILD_DIR"

echo "Restarting Thunar..."
thunar -q
pkill -f xdg-desktop-portal-gtk || true

echo "=== Done! Thunar selection highlights are square again. ==="
