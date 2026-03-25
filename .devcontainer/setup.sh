#!/usr/bin/env bash
set -euo pipefail

echo "=== Nest Dev Environment Setup ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/versions.env"

ANDROID_SDK_ROOT="/opt/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"

export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export NDK_HOME="$ANDROID_SDK_ROOT/ndk/${ANDROID_NDK_VERSION}"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$HOME/.cargo/bin:$HOME/.maestro/bin:$PATH"

echo "→ Installing base packages..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    git \
    python3 \
    python3-pip \
    unzip \
    wget \
    zip

echo "→ Installing Node.js ${NODE_MAJOR}.x..."
if ! command -v node >/dev/null 2>&1 || ! node --version | grep -q "^v${NODE_MAJOR}\."; then
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
fi

if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
    echo "→ Installing Android command line tools..."
    sudo mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    wget -q "$CMDLINE_TOOLS_URL" -O /tmp/cmdline-tools.zip
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extract
    sudo mv /tmp/cmdline-tools-extract/cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extract
    echo "✓ Command line tools installed"
else
    echo "✓ Command line tools already installed"
fi

echo "→ Accepting Android SDK licenses..."
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1

echo "→ Installing Android SDK components..."
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
    "platform-tools" \
    "platforms;${ANDROID_PLATFORM}" \
    "build-tools;${ANDROID_BUILD_TOOLS}" \
    "ndk;${ANDROID_NDK_VERSION}"
echo "✓ Android SDK components installed"

echo "→ Installing/aligning Rust ${RUST_VERSION}..."
if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "${RUST_VERSION}"
fi

# shellcheck source=/dev/null
source "$HOME/.cargo/env"
rustup toolchain install "${RUST_VERSION}" --profile minimal
rustup default "${RUST_VERSION}"

echo "→ Adding Android Rust targets..."
rustup target add aarch64-linux-android x86_64-linux-android

if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "→ Installing cargo-ndk..."
    cargo install cargo-ndk --locked
fi

if ! command -v maestro >/dev/null 2>&1; then
    echo "→ Installing Maestro CLI..."
    curl -Ls "https://get.maestro.mobile.dev" | bash
fi

echo "→ Initialising git submodules..."
git submodule update --init --recursive

if [ -f "zeroclaw/web/package.json" ]; then
    echo "→ Building web UI assets for local parity..."
    npm --prefix zeroclaw/web ci
    npm --prefix zeroclaw/web run build
fi

echo "→ Verifying core toolchain..."
required_commands=(git java sdkmanager rustc cargo cargo-ndk node npm python3 maestro)
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

echo ""
echo "=== Setup complete ==="
echo "Try: ./gradlew assembleDebug"
