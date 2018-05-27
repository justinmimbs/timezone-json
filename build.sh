#! /bin/bash

set -e

# ensure tz repository

if [ ! -d tz/.git ]; then
    git clone https://github.com/eggert/tz.git
else
    git -C tz checkout master && git -C tz pull
fi

# check latest version of tz

version=$(git -C tz describe --tags --abbrev=0)
tzdata="$(pwd -P)/tzdata/$version"
output="$(pwd -P)/dist/$version"

if [ -d "$output" ]; then
    echo "Existing build at 'dist/$version' is current."
    exit 0
fi

# make tzdata

git -C tz checkout $version
make -C tz install_data TOPDIR="$tzdata" REDO=posix_only

zoneinfo="$tzdata/usr/share/zoneinfo"
cp tz/zone.tab "$zoneinfo/zone.tab"

git -C tz checkout master

# ensure tzjs

tzjs=tzjs/compiled_to_json.py

if [ ! -f $tzjs ]; then
    mkdir tzjs
    touch tzjs/__init__.py
    curl "https://raw.githubusercontent.com/dbaron/tz.js/ea3d1b43fc5cc9b50e220c6a8d525d5eeb25f08f/compiled-to-json.py" -o $tzjs
fi

# build dist

./build.py "$zoneinfo" "$output"
echo "Created new build at 'dist/$version'."
