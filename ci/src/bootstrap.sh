#!/bin/bash
set -x
set -e

for _ in 1 2 3; do
  if ! command -v brew >/dev/null; then
    echo "Installing Homebrew ..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null || echo "failed."
  else
    echo "Homebrew installed."
    break
  fi
done

PATH=$PATH:/usr/local/bin
export HOMEBREW_NO_ANALYTICS=1
echo "Installing some dependencies"
brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig boost glm
brew install -f /vagrant/external/oce*tar.gz
