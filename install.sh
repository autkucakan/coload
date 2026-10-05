#!/usr/bin/env bash
set -euo pipefail

REPO="autkucakan/coload"
BRANCH="${COLOAD_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

BIN_DIR="$HOME/.local/bin"
COLOAD_BIN="$BIN_DIR/coload"
COLOAD_KEY="$HOME/.ssh/coload_ed25519"

echo "[coload] Installing..."

mkdir -p "$BIN_DIR" "$HOME/.ssh"

# Required system tools
for cmd in ssh rsync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: '$cmd' is required."
        echo "Ubuntu/Debian: sudo apt install openssh-client rsync"
        exit 1
    fi
done

# Find or install uv
if command -v uv >/dev/null 2>&1; then
    UV="$(command -v uv)"
elif [ -x "$BIN_DIR/uv" ]; then
    UV="$BIN_DIR/uv"
else
    echo "[coload] Installing uv..."

    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "error: curl or wget is required."
        exit 1
    fi

    UV="$BIN_DIR/uv"
fi

echo "[coload] Ensuring Python 3.12..."
"$UV" python install 3.12

echo "[coload] Installing Google Colab CLI..."
"$UV" tool install --python 3.12 google-colab-cli --force

export PATH="$BIN_DIR:$PATH"

if ! command -v colab >/dev/null 2>&1; then
    echo "error: Google Colab CLI installation failed."
    exit 1
fi

# Dedicated coload SSH key
if [ ! -f "$COLOAD_KEY" ]; then
    echo "[coload] Creating SSH key..."
    ssh-keygen -q -t ed25519 -N "" -f "$COLOAD_KEY"
fi

chmod 600 "$COLOAD_KEY"
chmod 644 "$COLOAD_KEY.pub"

# Install coload.
# Prefer local source when running from a cloned repository.
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"

if [ -n "$SCRIPT_SOURCE" ] && [ -f "$SCRIPT_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
    SCRIPT_DIR=""
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/coload" ]; then
    echo "[coload] Installing local coload..."
    install -m 755 "$SCRIPT_DIR/bin/coload" "$COLOAD_BIN"
else
    echo "[coload] Downloading coload..."

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_BASE/bin/coload" -o "$COLOAD_BIN"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$RAW_BASE/bin/coload" -O "$COLOAD_BIN"
    else
        echo "error: curl or wget is required."
        exit 1
    fi

    chmod 755 "$COLOAD_BIN"
fi

# Add ~/.local/bin to future shells
case "${SHELL:-}" in
    */zsh)  RC="$HOME/.zshrc" ;;
    */bash) RC="$HOME/.bashrc" ;;
    *)      RC="$HOME/.profile" ;;
esac

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

if ! grep -Fq "$PATH_LINE" "$RC" 2>/dev/null; then
    printf '\n%s\n' "$PATH_LINE" >> "$RC"
fi

echo
echo "[coload] Google authentication"
echo "Follow the Google authorization flow below."
echo

colab --auth=oauth2 sessions

echo
echo "[coload] Installed."
echo
echo "Run:"
echo "  coload python train.py"
