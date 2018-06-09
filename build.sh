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

echo ""
echo "Making tests"
echo ""
./maketests.py 1000 > examples/Tests/Local.elm

echo ""
echo "Compiling Elm examples"
echo ""
if [ -x "$(command -v elm)" ]; then
    ./elm make examples/compare/Main.elm --output examples/compare/main.js > /dev/null
fi

echo "To run tests, see examples, and compare to browser, start 'elm reactor' and open:

    http://localhost:8000/examples/Tests.elm
    http://localhost:8000/examples/Examples.elm
    http://localhost:8000/examples/ZoneInfo.elm
    http://localhost:8000/examples/compare/index.html
"
