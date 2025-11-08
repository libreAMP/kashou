#!/bin/bash
# Download Python runtime and yt-dlp for Android
set -e

PYTHON_VERSION="3.11"
ARCH="aarch64"  # arm64-v8a
ASSETS_DIR="src/main/assets/python"

echo "Creating assets directory..."
mkdir -p "$ASSETS_DIR"

# Download Python for Android from python-build-standalone
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-${PYTHON_VERSION}+20231002-${ARCH}-unknown-linux-gnu-install_only.tar.gz"

echo "Downloading Python ${PYTHON_VERSION} for ${ARCH}..."
wget -O /tmp/python.tar.gz "$PYTHON_URL"

echo "Extracting Python..."
cd "$ASSETS_DIR"
tar -xzf /tmp/python.tar.gz
mv python/* .
rmdir python

# Install yt-dlp and dependencies
echo "Installing yt-dlp..."
./bin/pip3 install --target=./lib/python${PYTHON_VERSION}/site-packages yt-dlp

echo "Cleaning up..."
rm -rf /tmp/python.tar.gz
rm -rf share/man
rm -rf lib/python${PYTHON_VERSION}/test
rm -rf lib/python${PYTHON_VERSION}/idlelib

echo "Python runtime with yt-dlp ready!"
echo "Size: $(du -sh . | cut -f1)"
