#! /usr/bin/python

import argparse
import random
import time


template = """module Tests.Local exposing (examples)


examples : List ( Int, String )
examples =
    [ %s
    ]
"""


def make_example(_):
    posix = random.randint(0, 2**31)
    localstring = time.strftime("%a %b %d %Y %H:%M:%S", time.localtime(posix))
    return "( %d, \"%s\" )" % (posix * 1000, localstring)


def make_examples(n):
    examples = map(make_example, range(0, n))
    return template % "\n    , ".join(examples)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("n", type=int)
    args = parser.parse_args()

    print make_examples(args.n)


if __name__ == "__main__":
    main()
