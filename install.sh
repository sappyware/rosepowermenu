
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="rosepowermenu"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/$APP_NAME"

FILES=(
    Config.qml
    PowerButton.qml
    PowerMenu.qml
    qmldir
    shell.qml
    Theme.qml
)

for file in "${FILES[@]}"; do
    if [[ ! -f "$SOURCE_DIR/$file" ]]; then
        printf 'error: missing required file: %s\n' "$file" >&2
        exit 1
    fi
done

if ! command -v qs >/dev/null 2>&1; then
    printf 'error: Quickshell (qs) is not installed or not in PATH.\n' >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"

for file in "${FILES[@]}"; do
    if [[ -f "$INSTALL_DIR/$file" ]]; then
        cp -n "$INSTALL_DIR/$file" "$INSTALL_DIR/$file.bak"
    fi

    install -m 644 "$SOURCE_DIR/$file" "$INSTALL_DIR/$file"
done

printf '\ninstalled to: %s\n' "$INSTALL_DIR"
printf 'launch with: qs -c %s\n' "$APP_NAME"
