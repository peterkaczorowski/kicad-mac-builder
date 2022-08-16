#!/bin/bash

# Build KiCad's dependencies for an Apple Silicon build, on an Apple Silicon system
# Run this from the same directory as build.py

echo "MacOS version: $(sw_vers -productVersion | cut -d. -f1-2)"
echo "Host architecture: $(sysctl -n machdep.cpu.brand_string)"
echo "'arch' output: $(arch)"
echo "PATH: $PATH"

if [ "$(arch)" != "arm64" ]; then
  echo "Expected 'arch' to return 'arm64'. Are you in a terminal running under Rosetta, maybe?"
  exit 1
fi

# Make sure that /opt/homebrew/bin is before a potential Rosetta'ed homebrew
echo "Temporarily prefixing PATH with /opt/homebrew/bin..."
export PATH="/opt/homebrew/bin:$PATH"

set -e

echo "Running build.py..."
./build.py --arch=arm64 --target setup-kicad-dependencies


# git clone https://gitlab.com/kicad/code/kicad.git ../kicad
# ./build.py --arch=arm64 --kicad-source-dir=../kicad --target=kicad


# Mixed reports about setting CFLAGS et al helping with mixed Brews
# CFLAGS="-I/$(brew --prefix)/include" CXXFLAGS="-I/$(brew --prefix)/include" ./build.py --arch=arm64 --kicad-source-dir=../kicad --target=kicad
