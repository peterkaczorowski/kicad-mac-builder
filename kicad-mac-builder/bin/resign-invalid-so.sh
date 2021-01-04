#!/bin/sh

# $1 : kicad.app path

for file in $(find $1 -type f -print | grep "\.so\|\.dylib"); do
    codesign --verify ${file}
    if [ "$?" -ne 0 ]; then
        echo "force resign ${file}"
        codesign --verify --force --sign "-" ${file}
    fi
done