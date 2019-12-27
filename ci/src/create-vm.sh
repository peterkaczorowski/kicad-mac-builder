#!/bin/bash

echo "This script creates a new base VM."

echo "This is for folks who want to test that kicad-mac-builder works on a 'clean machine' and isn't really meant for day-to-day development."

echo "This script assumes you have macinbox installed."

sudo macinbox --name macos1015-$(date '+%Y%m%d') --disk 80G --box-format vagrant --user-script bootstrap.sh
