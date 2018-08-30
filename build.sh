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
echo "Compiling tz data..."
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

echo "Converting tz data to JSON files..."
./build.py "$zoneinfo" "$output"
echo ""
echo "Created new build at 'dist/$version'."
echo ""

# make tests, compare/main.js

./maketests.py 1000 > tests/Local.elm

if [ -x "$(command -v elm)" ]; then
    elm make tests/compare/Main.elm --output tests/compare/main.js > /dev/null
fi

echo "To run tests, compare to browser, and see examples, start 'elm reactor' and open:

    http://localhost:8000/tests/Tests.elm
    http://localhost:8000/tests/compare/index.html
    http://localhost:8000/examples/GetZone.elm
    http://localhost:8000/examples/ZoneInfo.elm
"
