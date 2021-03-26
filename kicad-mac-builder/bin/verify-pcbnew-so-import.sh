#!/bin/bash

shopt -s nullglob # needed to error when we have a glob expansion

#TODO: $1 needs to be absolute path right now, let's fix that!

if [ ! -e "$1" ]; then
  echo "Cannot test $1 as it does not appear to exist."
  exit 1
fi

echo "Checking that importing pcbnew.so doesn't pull in a different Python or crash"
cd "$1"
cd Contents/Frameworks/Python.framework/Versions/Current/lib/python*/site-packages

PYTHON="$1/Contents/Frameworks/Python.framework/Versions/Current/bin/python3" # requires that $1 is absolute...
DYLD_PRINT_LIBRARIES=1 DYLD_PRINT_LIBRARIES_POST_LAUNCH=1 $PYTHON -c 'import pcbnew ; print("Imported" + "Module" + "Successfully")'

DYLD_PRINT_LIBRARIES=1 DYLD_PRINT_LIBRARIES_POST_LAUNCH=1 $PYTHON -c 'import pcbnew ; print("Imported" + "Module" + "Successfully")' 2>&1 | grep /System/Library/Frameworks/Python.framework
if [ "$?" -ne 1 ]; then
	echo "$1 appears to call the System Python framework.  DYLD_PRINT_LIBRARIES=1 \"$1\" may help you debug the issue."
	exit 1
fi

DYLD_PRINT_LIBRARIES=1 DYLD_PRINT_LIBRARIES_POST_LAUNCH=1 $PYTHON -c 'import pcbnew ; print("Imported" + "Module" + "Successfully")' 2>&1 | grep ImportedModuleSuccessfully
if [ "$?" -ne 0 ]; then
	echo "Error importing pcbnew."
	exit 1
fi