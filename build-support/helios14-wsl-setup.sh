#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 24.04 WSL2 bootstrap for JimVulkan/mali-panvk.
# Run after WSL2 + Ubuntu 24.04 have been installed by an elevated Windows user.
# This installs host dependencies only; it does not alter Android partitions or drivers.

sudo apt-get update
sudo apt-get install -y \
  build-essential git pkg-config python3 python3-pip python3-venv \
  python3-mako python3-packaging python3-yaml meson ninja-build \
  glslang-tools cmake curl unzip zip \
  llvm-21-dev libclang-21-dev clang-21 libclc-21-dev libllvmspirvlib-21-dev

echo
echo "Install Android NDK r29 (Linux host package) and set:"
echo '  export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/29.0.14206865"'
echo
echo "Build:"
echo '  cd ~/src/mali-panvk'
echo '  ./build.sh "$ANDROID_NDK_HOME"'
echo
echo "Expected output: dist/mali-panvk-27.0.0-devel-<commit>.zip"
