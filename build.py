#!/usr/bin/python

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
            changes.append(( time // 60, offset ))

    return ( changes, initial )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("zoneinfo", help="path to zoneinfo directory (compiled tz data)")
    parser.add_argument("output", help="path to destination directory")
    args = parser.parse_args()

    zoneinfo = os.path.abspath(args.zoneinfo)

    if not os.path.exists(zoneinfo):
        print "error: zoneinfo not found: " + zoneinfo
        sys.exit(1)

    # test with New_York for now
    tz_json = json.loads(tzjs.compiled_to_json.json_zones(zoneinfo))

    outfile = os.path.join(args.output, "America/New_York" + ".json")
    outcontent = make_zone(tz_json["America/New_York"])

    if not os.path.exists(os.path.dirname(outfile)):
        os.makedirs(os.path.dirname(outfile))

    output = io.open(outfile, "w", encoding="utf-8")
    output.write(unicode(json.dumps(outcontent), encoding="utf-8-sig"))
    output.close()


if __name__ == "__main__":
    main()
