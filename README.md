# timezone-json

Use the IANA time zone database (tzdb) to build a set of JSON files for all time zones. Each JSON file contains a time zone's offset at 1970 and a list of offset changes up to 2037. These can be used to compute local times from UTC times.

See the `examples` folder for examples of use with `elm/time`.

## Build

**Clone this project:**

```bash
git clone https://github.com/justinmimbs/timezone-json.git
```

**Per [evancz's recommendation][er] concerning the alpha/beta `elm` executables:**

> These are just binaries. I recommend copying them into whatever directory you want to work in. This way it will not mess with your `PATH` or stop you from working with 0.18 in the meantime.

Hence, copy your `elm` 0.19 executable into this project now.

**Now build everything:**

```bash
./build.sh
```

## Result

* clones the [IANA time zone database repository][tz]
* compiles time zone information files for the latest release
* uses a script from [tz.js][tzjs] to read the compiled files
* writes a set of JSON files to `dist/<version>`

For example, if the latest tzdb release is version `2018e`, then the file for "America/Los_Angeles" will be written to `dist/2018e/America/Los_Angeles.json`.

[er]: https://gist.github.com/evancz/8e89512dfa9f68903f05f1ac4c44861b
[tz]: https://github.com/eggert/tz
[tzjs]: https://github.com/dbaron/tz.js
