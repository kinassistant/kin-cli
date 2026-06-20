#!/usr/bin/env sh
# KIN CLI installer (REQUIREMENTS.md §11). No-Homebrew fallback for macOS/Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/kinassistant/kin-cli/main/install.sh | sh
#
# Env overrides: KIN_VERSION (tag, default latest), KIN_INSTALL_DIR.
set -eu

REPO="kinassistant/kin-cli"
BIN="kin"

info() { printf '\033[36m==>\033[0m %s\n' "$1"; }
err() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) err "unsupported architecture: $arch" ;;
esac
case "$os" in
  darwin|linux) ;;
  *) err "unsupported OS: $os (Windows is not yet supported)" ;;
esac

version="${KIN_VERSION:-}"
if [ -z "$version" ]; then
  info "Resolving latest release…"
  version="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -m1 '"tag_name"' | cut -d'"' -f4)"
  [ -n "$version" ] || err "could not determine latest version"
fi
# Strip a leading cli- prefix from the tag for the archive version segment.
ver_num="${version#cli-}"
ver_num="${ver_num#v}"

# macOS ships a universal binary; Linux is per-arch.
if [ "$os" = "darwin" ]; then
  asset="${BIN}_${ver_num}_darwin_all.tar.gz"
else
  asset="${BIN}_${ver_num}_${os}_${arch}.tar.gz"
fi
url="https://github.com/$REPO/releases/download/$version/$asset"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
info "Downloading $asset…"
curl -fsSL "$url" -o "$tmp/$asset" || err "download failed: $url"
tar -xzf "$tmp/$asset" -C "$tmp" || err "extract failed"

dir="${KIN_INSTALL_DIR:-}"
if [ -z "$dir" ]; then
  if [ -w "/usr/local/bin" ] 2>/dev/null; then
    dir="/usr/local/bin"
  else
    dir="$HOME/.local/bin"
  fi
fi
mkdir -p "$dir"
install -m 0755 "$tmp/$BIN" "$dir/$BIN" 2>/dev/null || { mv "$tmp/$BIN" "$dir/$BIN"; chmod 0755 "$dir/$BIN"; }

info "Installed $BIN $ver_num to $dir/$BIN"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) printf '\033[33mnote:\033[0m add %s to your PATH\n' "$dir" ;;
esac
info "Run 'kin' to get started. (Voice input needs sox: brew install sox)"
