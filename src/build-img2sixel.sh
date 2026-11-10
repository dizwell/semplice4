#!/usr/bin/env bash
# Builds img2sixel (libsixel) for the current machine and puts it in
# ../exec/ as img2sixel-<macos|linux>-<arm64|x86_64>.
# libsixel's own built-in image reader handles JPG and PNG, so no JPEG or PNG
# libraries are used: the result depends on nothing outside itself.
#   Linux: fully static.
#           Needs: gcc, make, git (Debian: sudo apt install build-essential git)
#   MacOS: uses nothing beyond MacOS itself, so needs only the Xcode command line
#           tools. On a Mac, add x86_64 or arm64 to build for the other processor
#           type (e.g. ./build-img2sixel.sh x86_64)
set -e

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64)        ARCH="x86_64" ;;
  *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac

# On a Mac, an optional argument picks the target processor (cross-compiling)
if [[ $PLATFORM == "macos" && -n $1 ]]; then
  case "$1" in
    arm64|x86_64) ARCH="$1" ;;
    *) echo "Unknown target: $1 (use arm64 or x86_64)"; exit 1 ;;
  esac
fi

OUTDIR="$(cd "$(dirname "$0")/.." && pwd)/exec"
OUTFILE="$OUTDIR/img2sixel-$PLATFORM-$ARCH"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "Fetching libsixel source..."
git clone -q --depth 1 https://github.com/saitoha/libsixel.git
cd libsixel

# Brand it with Semplice and Giocoso's version label, as Giocoso's rebuild scripts do
VERSION_STRING="bbritten-4.0.0"
if ! grep -q "PACKAGE_VERSION='1.8.7-r2'" configure; then
  echo "ERROR: libsixel package version definition has changed."
  exit 1
fi
sed -i.orig "s/1\.8\.7-r2/$VERSION_STRING/g" configure

if [[ $PLATFORM == "macos" ]]; then
  if [[ $ARCH == "arm64" ]]; then MINVER="11.0"; else MINVER="10.13"; fi
  export CFLAGS="-O2 -arch $ARCH -mmacosx-version-min=$MINVER"
  export LDFLAGS="-arch $ARCH -mmacosx-version-min=$MINVER"
  HOSTOPT="--host=$ARCH-apple-darwin"
  [[ $ARCH == "arm64" ]] && HOSTOPT="--host=aarch64-apple-darwin"
  MAKELDFLAGS="$LDFLAGS"
else
  export CFLAGS="-O2"
  HOSTOPT=""
  MAKELDFLAGS="-all-static"
fi

echo "Configuring libsixel..."
./configure $HOSTOPT --disable-shared --enable-static --disable-python \
  --without-libcurl --without-gd --without-gdk-pixbuf2 --without-jpeg --without-png >/dev/null

echo "Building img2sixel..."
make -C src >/dev/null 2>&1
make -C converters LDFLAGS="$MAKELDFLAGS" img2sixel >/dev/null 2>&1
cp converters/img2sixel "$OUTFILE"
strip "$OUTFILE"

echo
echo "Built: $OUTFILE"
file "$OUTFILE"
"$OUTFILE" --version | head -1
