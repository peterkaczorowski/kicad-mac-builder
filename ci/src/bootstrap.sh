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
echo "Updating SSH"
brew install openssh
echo "Installing some dependencies"
if sw_vers | grep ^ProductVersion | grep ' 10.14' > /dev/null ; then
  echo "Installing opencascade from bottle"
  brew install external/opencascade*mojave*
  echo "Installing the rest of the dependencies"
  brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig boost glm openssl
else
  brew install glew cairo doxygen gettext wget bison libtool autoconf automake cmake swig opencascade boost glm openssl
fi
