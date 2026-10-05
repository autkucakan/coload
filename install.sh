#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CRUN_BIN="$BIN_DIR/crun"
CRUN_KEY="$HOME/.ssh/crun_ed25519"

echo "[crun] Installing..."

# Required system commands
for cmd in ssh rsync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: '$cmd' is required."
        echo "Ubuntu/Debian: sudo apt install openssh-client rsync"
        exit 1
    fi
done

mkdir -p "$BIN_DIR" "$HOME/.ssh"

# Install uv if missing
if command -v uv >/dev/null 2>&1; then
    UV="$(command -v uv)"
elif [ -x "$BIN_DIR/uv" ]; then
    UV="$BIN_DIR/uv"
else
    echo "[crun] Installing uv..."

    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "error: curl or wget is required to install uv."
        exit 1
    fi

    UV="$BIN_DIR/uv"
fi

# Colab CLI requires Python >=3.12
echo "[crun] Ensuring Python 3.12..."
"$UV" python install 3.12

# Install/update Colab CLI
echo "[crun] Installing Google Colab CLI..."
"$UV" tool install --python 3.12 google-colab-cli --force

export PATH="$BIN_DIR:$PATH"

if ! command -v colab >/dev/null 2>&1; then
    echo "error: Colab CLI installation failed."
    exit 1
fi

# Dedicated key. Never modify user's existing SSH keys.
if [ ! -f "$CRUN_KEY" ]; then
    echo "[crun] Creating dedicated SSH key..."
    ssh-keygen -q -t ed25519 -N "" -f "$CRUN_KEY"
fi

chmod 600 "$CRUN_KEY"
chmod 644 "$CRUN_KEY.pub"

# Install crun
install -m 755 "$REPO_DIR/bin/crun" "$CRUN_BIN"

# Ensure ~/.local/bin is available in future shells
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
echo "[crun] Google authentication"
echo "Follow the URL below and paste the authorization code when requested."
echo

# Read-only call. Triggers OAuth login without provisioning a VM.
colab --auth=oauth2 sessions

echo
echo "[crun] Installed successfully."
echo "Usage:"
echo "  cd your-project"
echo "  crun python train.py"
