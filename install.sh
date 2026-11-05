#!/bin/sh
set -eu

REPO="zankros/kerf"
REF="${KERF_REF:-master}"
PREFIX="${KERF_PREFIX:-$HOME/.local}"
TMPDIR="${TMPDIR:-/tmp}"
WORK="$TMPDIR/kerf-install-$$"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "kerf: missing required command: $1" >&2
    exit 1
  }
}

need curl
need tar
need guile
need make

mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

echo "fetching kerf..."
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$REF.tar.gz" -o "$WORK/kerf.tar.gz"
tar -xzf "$WORK/kerf.tar.gz" -C "$WORK"
SRC=$(find "$WORK" -mindepth 1 -maxdepth 1 -type d | head -n 1)

make -C "$SRC" install PREFIX="$PREFIX"

echo
echo "installed kerf to $PREFIX/bin/kerf"
case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) echo "add $PREFIX/bin to your PATH to run kerf" ;;
esac