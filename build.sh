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
    echo ""
    echo "Existing build at 'dist/$version' is current."
    echo ""
    exit 0
fi

# make tzdata

git -C tz -c advice.detachedHead=false checkout $version
make -C tz install_data TOPDIR="$tzdata" REDO=posix_only > /dev/null

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
echo ""
echo "Created new build at 'dist/$version'."
echo ""

# make tests, compare/main.js

./maketests.py 1000 > elm/Tests/Local.elm

if [ -x "$(command -v elm)" ]; then
    elm make elm/compare/Main.elm --output elm/compare/main.js > /dev/null
fi

echo "To run tests, see examples, and compare to browser, start 'elm reactor' and open:

    http://localhost:8000/elm/Tests.elm
    http://localhost:8000/elm/Examples.elm
    http://localhost:8000/elm/compare/index.html
"
