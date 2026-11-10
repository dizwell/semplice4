#!/usr/bin/env bash
# Builds sacd_extract (EuFlo fork) for the current machine and puts it in
# ../exec/ as sacd_extract-<macos|linux>-<arm64|x86_64>.
#   Linux: fully static (libxml2 built from source and linked in).
#           Needs: gcc, cmake, git (Debian: sudo apt install build-essential cmake git)
#   MacOS: links the libxml2 and libiconv that ship with MacOS, so needs nothing
#           beyond the Xcode command line tools.
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

OUTDIR="$(cd "$(dirname "$0")/.." && pwd)/exec"
OUTFILE="$OUTDIR/sacd_extract-$PLATFORM-$ARCH"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "Fetching sacd-ripper source..."
git clone -q --depth 1 https://github.com/EuFlo/sacd-ripper.git

if [[ $PLATFORM == "linux" ]]; then
  echo "Building a static libxml2..."
  git clone -q --depth 1 --branch v2.13.8 https://github.com/GNOME/libxml2.git 2>/dev/null
  cmake -S libxml2 -B libxml2/build -DBUILD_SHARED_LIBS=OFF -DLIBXML2_WITH_PYTHON=OFF \
    -DLIBXML2_WITH_ZLIB=OFF -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_ICU=OFF \
    -DLIBXML2_WITH_HTTP=OFF -DLIBXML2_WITH_FTP=OFF -DLIBXML2_WITH_PROGRAMS=OFF \
    -DLIBXML2_WITH_TESTS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$WORK/xml" >/dev/null
  cmake --build libxml2/build -j4 >/dev/null
  cmake --install libxml2/build >/dev/null
  XMLINC="-I$WORK/xml/include/libxml2"
  LINK="-static -L$WORK/xml/lib -lxml2 -lpthread -lm"
else
  SDK=$(xcrun --show-sdk-path)
  XMLINC="-I$SDK/usr/include/libxml2"
  if [[ $ARCH == "arm64" ]]; then MINVER="11.0"; else MINVER="10.13"; fi
  LINK="-mmacosx-version-min=$MINVER -lxml2 -liconv"
fi

echo "Building sacd_extract..."
cd sacd-ripper
L=libs
SRC=$(ls tools/sacd_extract/*.c $L/libcommon/*.c $L/libdstdec/*.c $L/libid3/*.c $L/libsacd/*.c \
      | grep -v -E "usocket.c|wsocket.c|dst_decoder_ps3.c|/ioctl.c|sac_accessor.c")
cc -O2 -w -D_FILE_OFFSET_BITS=64 -Itools/sacd_extract -I$L/libcommon -I$L/libdstdec \
   -I$L/libid3 -I$L/libsacd $XMLINC $SRC $LINK -o "$OUTFILE" 2>&1 | grep -v -i -E "warning|gethostby" || true
strip "$OUTFILE"

echo
echo "Built: $OUTFILE"
file "$OUTFILE"
