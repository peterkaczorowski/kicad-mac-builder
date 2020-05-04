#!/bin/bash
set -x
set -e

# Easy hack to get a timeout command
function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

for _ in 1 2 3; do
  if ! command -v brew >/dev/null; then
    echo "Installing Homebrew ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" < /dev/null 
  else
    echo "Homebrew installed."
    break
  fi
done

PATH=$PATH:/usr/local/bin
export HOMEBREW_NO_ANALYTICS=1
echo "Installing openssl to debug it, it often fails on make test..."
timeout 1800 brew install --verbose openssl
echo "Installing some dependencies"
brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig boost glm
brew install -f /vagrant/external/oce*tar.gz
