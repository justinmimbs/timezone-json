#! /usr/bin/python

import argparse
import calendar
import io
import json
import os
import sys

import tzjs.compiled_to_json


START_TIME = 0

UNTIL_TIME = calendar.timegm((2038, 1, 1, 0, 0, 0))


def make_zone(tzjs_zone):
    changes = []
    initial = 0
    currentoffset = None

    for time, idx in zip(tzjs_zone["times"], tzjs_zone["ltidx"]):
        offset = int(round(tzjs_zone["types"][idx]["o"] / 60.0))

        if time <= START_TIME:
            initial = offset

        elif time < UNTIL_TIME and offset != currentoffset:
            changes.append(( int(round(time / 60.0)), offset ))

        currentoffset = offset

    changes.reverse()
    return ( changes, initial )


def create_jsonfile(filepath, filecontent):
    if not os.path.exists(os.path.dirname(filepath)):
       os.makedirs(os.path.dirname(filepath))

    output = io.open(filepath, "w", encoding="utf-8")
    output.write(unicode(json.dumps(filecontent), encoding="utf-8-sig"))
    output.close()


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

    # write zone files
    for zonename, tzjs_zone in tzjs_json.iteritems():
        filepath = os.path.join(args.output, zonename + ".json")
        filecontent = make_zone(tzjs_zone)
        create_jsonfile(filepath, filecontent)

    # write zones.json
    create_jsonfile(os.path.join(args.output, "zones.json"), sorted(tzjs_json.keys()))


if __name__ == "__main__":
    main()
