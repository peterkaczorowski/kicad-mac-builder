#!/bin/bash
set -x
set -e

# This is a modified bootstrap.sh to support the 5.x releases on 10.12.

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
# echo "Updating SSH"
# brew install openssh
echo "Installing some dependencies"
brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig opencascade boost glm openssl zlib
brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig boost glm openssl zlib
brew install -f /vagrant/external/oce*tar.gz
