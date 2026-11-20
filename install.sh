#!/bin/sh
# thumb installer: https://thumbplan.date
#
#   curl -fsSL https://thumbplan.date/install.sh | sh
#
# Downloads the latest thumb release for your OS and CPU from GitHub, checks
# its SHA-256 checksum, and puts the binary on your PATH. No sudo unless you ask.
#
# Options (environment variables):
#   THUMB_VERSION=v0.2.0       install a specific release instead of the latest
#   THUMB_INSTALL_DIR=~/bin    install somewhere specific
#   THUMB_DOWNLOAD_BASE=URL    fetch release files from a mirror (or a test server)
#
# Everything is wrapped in main() and only runs on the last line, so a
# download that gets cut off halfway can't run half a script.

set -eu

REPO="mattroyer/thumb"   # the GitHub repo that publishes thumb releases

main() {
  base="${THUMB_DOWNLOAD_BASE:-}"
  version="${THUMB_VERSION:-latest}"

  need uname
  need tar
  need mktemp

  os=$(uname -s)
  case "$os" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    FreeBSD) os=freebsd ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
      fail "on Windows, download thumb from https://github.com/$REPO/releases" ;;
    *) fail "unsupported operating system: $os" ;;
  esac

  arch=$(uname -m)
  case "$arch" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) fail "unsupported CPU: $arch" ;;
  esac
  # An Apple Silicon Mac running this shell under Rosetta reports x86_64.
  if [ "$os" = darwin ] && [ "$arch" = amd64 ] &&
    [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then
    arch=arm64
  fi

  if [ -z "$base" ]; then
    if [ "$version" = latest ]; then
      base="https://github.com/$REPO/releases/latest/download"
    else
      case "$version" in v*) ;; *) version="v$version" ;; esac
      base="https://github.com/$REPO/releases/download/$version"
    fi
  fi

  archive="thumb_${os}_${arch}.tar.gz"
  tmp=$(mktemp -d 2>/dev/null || mktemp -d -t thumb)
  trap 'rm -rf "$tmp"' EXIT INT TERM

  say "Downloading thumb ($version) for $os/$arch..."
  download "$base/$archive" "$tmp/$archive" ||
    fail "couldn't download $archive (is there a release for $os/$arch?)"
  download "$base/checksums.txt" "$tmp/checksums.txt" ||
    fail "couldn't download checksums.txt"

  expected=$(awk -v f="$archive" '$2 == f || $2 == "*" f { print $1 }' "$tmp/checksums.txt")
  [ -n "$expected" ] || fail "$archive isn't listed in checksums.txt"
  actual=$(sha256 "$tmp/$archive")
  [ "$expected" = "$actual" ] ||
    fail "checksum mismatch for $archive; refusing to install (expected $expected, got $actual)"

  tar -xzf "$tmp/$archive" -C "$tmp" thumb ||
    fail "the archive doesn't contain a thumb binary"
  chmod +x "$tmp/thumb"

  dir=$(pick_dir)
  mkdir -p "$dir"
  mv -f "$tmp/thumb" "$dir/thumb"
  # curl doesn't set macOS's quarantine flag, but clear it in case something did.
  if [ "$os" = darwin ] && command -v xattr >/dev/null 2>&1; then
    xattr -d com.apple.quarantine "$dir/thumb" 2>/dev/null || true
  fi

  say "Installed $("$dir/thumb" version 2>/dev/null || echo thumb) to $dir/thumb"
  on_path "$dir" || path_hint "$dir"
  say ""
  say "Read someone's plan:  thumb <their handle>"
  say "Write your own:       thumb login, then thumb edit"
}

# Install where an existing thumb already is, then $THUMB_INSTALL_DIR,
# then /usr/local/bin if it's writable without sudo, then ~/.local/bin.
pick_dir() {
  if [ -n "${THUMB_INSTALL_DIR:-}" ]; then
    case "$THUMB_INSTALL_DIR" in
      "~"/*) echo "$HOME/${THUMB_INSTALL_DIR#"~/"}" ;;
      *) echo "$THUMB_INSTALL_DIR" ;;
    esac
    return
  fi
  existing=$(command -v thumb 2>/dev/null || true)
  if [ -n "$existing" ] && [ -w "$(dirname "$existing")" ]; then
    dirname "$existing"
    return
  fi
  if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    echo /usr/local/bin
    return
  fi
  echo "$HOME/.local/bin"
}

on_path() {
  case ":$PATH:" in *":$1:"*) return 0 ;; *) return 1 ;; esac
}

path_hint() {
  # The ~ paths below are display text for the user, not paths to expand.
  shell_rc="your shell's startup file"
  # shellcheck disable=SC2088
  case "${SHELL:-}" in
    */zsh) shell_rc="~/.zshrc" ;;
    */bash) shell_rc="~/.bashrc" ;;
    */fish) shell_rc="~/.config/fish/config.fish" ;;
  esac
  say ""
  say "Note: $1 isn't on your PATH yet. Add this line to $shell_rc:"
  case "${SHELL:-}" in
    */fish) say "  fish_add_path $1" ;;
    *) say "  export PATH=\"$1:\$PATH\"" ;;
  esac
  say "then open a new terminal."
}

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 2 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fail "need curl or wget"
  fi
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v sha256 >/dev/null 2>&1; then
    sha256 -q "$1"
  else
    fail "need sha256sum or shasum to verify the download"
  fi
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "this installer needs '$1'"
}

say() { printf '%s\n' "$*"; }
fail() { printf 'thumb install: %s\n' "$*" >&2; exit 1; }

main "$@"
