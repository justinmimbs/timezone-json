#! /bin/bash

set -e

# ensure tz repository

if [ ! -d tz/.git ]; then
    git clone https://github.com/eggert/tz.git
else
    git -C tz checkout main && git -C tz pull
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

start=0 # 1970-01-01
end=2145916800 # 2038-01-01

git -C tz -c advice.detachedHead=false checkout $version
echo "Compiling tz data..."
make -C tz --quiet install_data TOPDIR="$tzdata" REDO=posix_only ZFLAGS="-b slim -r @$start/@$end"

zoneinfo="$tzdata/usr/share/zoneinfo"
cp tz/zone.tab "$zoneinfo/zone.tab"

git -C tz checkout main

# ensure tzjs

tzjs=tzjs/compiled_to_json.py

if [ ! -f $tzjs ]; then
    mkdir tzjs
    touch tzjs/__init__.py
    curl "https://raw.githubusercontent.com/dbaron/tz.js/06edde418046e02f8ba1828859890e30393469b0/compiled-to-json.py" -o $tzjs
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
    elm make tests/Compare.elm --output tests/compare/main.js > /dev/null
fi

echo "To run tests, compare to browser, and see examples, start 'elm reactor' and open:

    http://localhost:8000/tests/Tests.elm
    http://localhost:8000/tests/compare/index.html
    http://localhost:8000/examples/GetZone.elm
    http://localhost:8000/examples/ZoneInfo.elm
"
