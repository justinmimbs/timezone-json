#! /usr/bin/python

import argparse
import io
import json
import os
import sys

import tzjs.compiled_to_json


def make_zone(tzjs_zone):
    changes = []
    initial = 0

    for (time, idx) in reversed(zip(tzjs_zone["times"], tzjs_zone["ltidx"])):
        offset = tzjs_zone["types"][idx]["o"] // 60
        if time == 0:
            initial = offset
        else:
            changes.append((time // 60, offset))

    return (changes, initial)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("zoneinfo", help="path to zoneinfo directory (compiled tz data)")
    parser.add_argument("output", help="path to destination directory")
    args = parser.parse_args()

    zoneinfo = os.path.abspath(args.zoneinfo)

    if not os.path.exists(zoneinfo):
        print "error: zoneinfo not found: " + zoneinfo
        sys.exit(1)

    # convert compiled tzdata to tz.js json format
    tzjs_json = json.loads(tzjs.compiled_to_json.json_zones(zoneinfo))

    # write files
    for (zonename, tzjs_zone) in tzjs_json.items():
        filepath = os.path.join(args.output, zonename + ".json")
        filecontent = make_zone(tzjs_zone)

        if not os.path.exists(os.path.dirname(filepath)):
           os.makedirs(os.path.dirname(filepath))

        output = io.open(filepath, "w", encoding="utf-8")
        output.write(unicode(json.dumps(filecontent), encoding="utf-8-sig"))
        output.close()


if __name__ == "__main__":
    main()
